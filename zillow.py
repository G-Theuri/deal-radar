from nodriver import *
import nodriver as uc
from rich import print as rprint
import json
import asyncio
import base64

page_loaded = asyncio.Event()
async def main():
    browser = await uc.start()
    tab = browser.main_tab

    
    async def on_request_paused(event: uc.cdp.fetch.RequestPaused):
        request_id= event.request_id
        url = event.request.url
        if "async-create-search-page-state"  in url:
            try:
                response =  await tab.send(cdp.fetch.get_response_body(request_id=request_id))
                body, is_base64_encoded = response

                if is_base64_encoded:
                    body = base64.b64decode(body).decode('utf-8')

                print("--- Captured JSON Response ---")
                data = json.dumps(json.loads(body), indent=4)
                with open ("output.json", "w") as f:
                    f.write(data)
                rprint(data)
                page_loaded.set()

            except Exception as e:
                print(f"Error reading body: {e}")

        try:
            await tab.send(cdp.fetch.continue_request(request_id=request_id))
        except Exception:
            pass



    tab.add_handler(cdp.fetch.RequestPaused, on_request_paused)

    await tab.get("https://www.zillow.com/tn/?search")
    await tab.send(cdp.fetch.enable(patterns=[cdp.fetch.RequestPattern(url_pattern="*", request_stage=cdp.fetch.RequestStage.RESPONSE)]))
    print("Fetch domain successfully enabled.")
    await page_loaded.wait()
    browser.stop()
    

    


if __name__ == "__main__":
    uc.loop().run_until_complete(main())