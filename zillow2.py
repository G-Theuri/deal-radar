from nodriver import *
import nodriver as uc
from rich import print as rprint
import json
import asyncio
import base64
from loguru import logger

logger.add("zillow_scraper.log", enqueue=True)
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

                    data = json.dumps(json.loads(body), indent=4)
                    rprint(data)
                    print("Response body extracted.")
                    page_loaded.set()

                except Exception as e:
                        logger.error(f"Error reading response body: {e}")
        finally:
            await tab.send(cdp.fetch.continue_request(request_id=request_id))

    return on_request_paused

async def main():
    page_loaded = asyncio.Event()
    logger.info("'Page Loaded' Event Created.")

    logger.info("Initializing the browser...")
    browser = await uc.start()
    tab = browser.main_tab

    on_request_paused = events(tab, page_loaded)

    tab.add_handler(cdp.fetch.RequestPaused, on_request_paused)
    logger.info("Added a handler for 'RequestPaused' events.")

    logger.info("Navigating to Zillow...")
    await tab.get("https://www.zillow.com/tn/?search")

    await tab.send(cdp.fetch.enable(patterns=[cdp.fetch.RequestPattern(url_pattern="*", request_stage=cdp.fetch.RequestStage.RESPONSE)]))
    logger.info("Fetch enabled")

    await page_loaded.wait()
    logger.info('Scraper ran succesfully!')
    logger.info('Closing browser...')
    browser.stop()  


if __name__ == "__main__":
    uc.loop().run_until_complete(main())