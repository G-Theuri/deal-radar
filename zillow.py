from nodriver import *
import nodriver as uc
from rich import print
import json
import asyncio


async def main():
    browser = await start()
    tab = await browser.get('about:blank')
    search_data = {}
    captured = asyncio.Event()

    await tab.send(uc.cdp.network.enable())
    
    async def on_response(event: uc.cdp.network.ResponseReceived):
        if "async-create-search-page-state" not in event.response.url:
            return
        try:
            body = await tab.send(uc.cdp.network.get_response_body(event.request_id))

            search_data["body"] = json.loads(body.body)
            print("Captured:", search_data["body"])
            captured.set()

        except Exception as e:
            print(f"Failed to get body: {e}")

    tab.add_handler(uc.cdp.network.ResponseReceived, on_response)

    await tab.get("https://www.zillow.com/tn/?search")

    await asyncio.wait_for(captured.wait(), timeout=15)
    

    


if __name__ == "__main__":
    loop().run_until_complete(main())