import json
import requests
import pandas as pd
from io import StringIO
from pathlib import Path

# ------------------- 1. Load the Query Object and Table ID -------------------

config_path = Path("data/directEstimate.json")

with config_path.open("r", encoding="utf-8") as f:
    cfg = json.load(f)

payload = cfg["queryObj"]
table_id = cfg["tableIdForQuery"]

# ------------------- 2. Build the API URL -------------------

url = f"https://api.scb.se/OV0104/v1/doris/en/ssd/START/AM/AM0401/AM0401N/{table_id}"
headers = {"Content-Type": "application/json"}

# ------------------- 3. Fetch the Data -------------------

r = requests.post(url, json=payload, headers=headers)
r.raise_for_status()  # Raise an error if the request failed

# ------------------- 4. Parse According to Response Format -------------------

fmt = payload.get("response", {}).get("format", "").lower()

# Make sure 'data/' directory exists
data_dir = Path("data")
data_dir.mkdir(parents=True, exist_ok=True)

if fmt == "csv":
    # If the response is CSV format, read it into a DataFrame
    df = pd.read_csv(StringIO(r.text), sep=",")

    # Pick and rename the important columns
    df_selected = df.rename(columns={
        "region": "County",
        "Percent 2025K1": "Percent_2025K1",
        "Margin of error ± percent 2025K1": "Percent_2025K1_me"
    })[["County", "Percent_2025K1", "Percent_2025K1_me"]]

    # Clean the 'County' names: remove leading numbers and "county" word
    df_selected["County"] = (
        df_selected["County"]
        .str.replace(r"^\d+\s+", "", regex=True)     # Remove leading numbers and spaces
        .str.replace(r"\scounty$", "", regex=True)   # Remove " county" at the end
        .str.strip()                                 # Remove any leading/trailing whitespace
    )

    # Save the cleaned DataFrame to CSV
    output_filename = "direct_estimates.csv"
    out_csv = data_dir / output_filename
    df_selected.to_csv(out_csv, index=False)
    print(f"✅ Data saved to {out_csv.resolve()}")

elif fmt == "px":
    # If the response is PX format, save it as a PX file
    output_filename = f"{table_id}.px"
    out_px = data_dir / output_filename
    out_px.write_text(r.text, encoding="utf-8")
    print(f"✅ PC-Axis file saved to {out_px.resolve()}")

    # (Optional) Code example to read PX file later:
    # import pxpy
    # table = pxpy.read_pxd(str(out_px))
    # df = table.to_dataframe()
    # print(df.head())

else:
    # If the format is unknown, print the raw response
    print("⚠️ Response format not recognized. Here is the raw text:")
    print(r.text)
