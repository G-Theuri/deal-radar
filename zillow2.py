from nodriver import *
import nodriver as uc
from rich import print as rprint
import json
import asyncio
import base64
from loguru import logger
from supabase import create_client
from pydantic import BaseModel
import sys, os
from dotenv import load_dotenv
load_dotenv()

logger.add("zillow_scraper.log", enqueue=True)
queue = asyncio.Queue()
supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_KEY'))
class HdpData(BaseModel):
    homeInfo:HomeInfo | None = None

class HomeInfo(BaseModel):
    bathrooms: float
    bedrooms:int
    livingArea:float
    homeType:str
    homeStatus:str
    homeStatusForHDP:str
    # daysOnZillow: int | None = None
    isUnmappable: bool | None = None
    shouldHighlight: bool | None = None

    price: float
    priceChange: str | None = None
    priceReduction: str | None = None
    currency: str
    priceForHDP:float | None = None
    taxAssessedValue: float
    lotAreaValue: float | None = None
    zestimate:int | None = None
    rentZestimate: int | None = None

    streetAddress: str
    zipcode: str
    city: str
    state: str
    country: str
    latitude: float
    longitude: float

    timeOnZillow: int
    lotAreaUnit: str

class ListingsData(BaseModel):
    zpid: str
    detailUrl:str
    hdpData: HdpData
    statusType: str
    statusText: str
    rawHomeStatusCd: str
    marketingStatusSimplifiedCd: str

    flexFieldText: str | None = None
    has3DModel: bool 
    hasVideo: bool

    priceLabel: str
    address: str

    imgSrc: str
    isFeaturedListing: bool
    isShowcaseListing: bool
    isPaidBuilderNewConstruction: bool
    # availabilityDate: str | None = None
    brokerName: str
    


def events(tab, page_loaded):

    async def on_request_paused(event: uc.cdp.fetch.RequestPaused):
        request_id = event.request_id
        url = event.request.url
        try:
            if "async-create-search-page-state" in url:
                try:
                    logger.info(f"Target request intercepted: {url}")
                    response = await tab.send(cdp.fetch.get_response_body(request_id=request_id))
                    body, is_base64_encoded = response

                    if is_base64_encoded:
                        body = base64.b64decode(body).decode('utf-8')

                    data = json.loads(body)
                    with open ("newest-output.json", "w") as f:
                        f.write(json.dumps(data, indent=4))

                    # rprint(data)
                    print("Response body extracted.")
                    await queue.put(data)

                    page_loaded.set()

                except Exception as e:
                        logger.error(f"Error reading response body: {e}")
        finally:
            await tab.send(cdp.fetch.continue_request(request_id=request_id))

    return on_request_paused

async def process_data():
    info = []
    while True:
        data = await queue.get()
        
        try:
            listings = data['cat1']['searchResults']['mapResults']

            for listing in listings:
                listing['detailUrl'] = "https://www.zillow.com" + listing['detailUrl']
                item = ListingsData.model_validate(listing)
                data = item.model_dump()

                home_info = data.pop("hdpData", {}).get("homeInfo", {})
                data.update(home_info)

                rprint(data)
                info.append(data)
                break

            pass
        except Exception as e:
            print(f"{e}")

        finally:
            supabase.table("properties").upsert(info).execute()
            queue.task_done()
async def main():
    page_loaded = asyncio.Event()
    logger.info("─" * 110)
    logger.info("'Page Loaded' Event Created.")

    logger.info("Initializing the browser...")
    browser = await uc.start()
    tab = browser.main_tab

    on_request_paused = events(tab, page_loaded)

    tab.add_handler(cdp.fetch.RequestPaused, on_request_paused)
    logger.info("Added a handler for 'RequestPaused' events.")

    logger.info("Starting a data consumer to run in the background...")
    asyncio.create_task(process_data())

    logger.info("Navigating to Zillow...")
    await tab.get("https://www.zillow.com/tn/?search")
    await tab.evaluate("1+1") #Just a meaningless page interaction to trigger lazy loading

    await tab.send(cdp.fetch.enable(patterns=[cdp.fetch.RequestPattern(url_pattern="*", request_stage=cdp.fetch.RequestStage.RESPONSE)]))
    logger.info("Fetch enabled")


    await page_loaded.wait()
    logger.info('Scraper ran succesfully!')
    logger.info('Closing browser...')
    logger.info("─" * 110)
    browser.stop()  


if __name__ == "__main__":
    uc.loop().run_until_complete(main())