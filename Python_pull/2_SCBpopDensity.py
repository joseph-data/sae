import json
import requests
import pandas as pd
import re
from io import StringIO
from pathlib import Path

# 1. Load the query object and table ID from disk
config_path = Path("data/popdensity.json")
with config_path.open("r", encoding="utf-8") as f:
    cfg = json.load(f)

payload = cfg["queryObj"]
table_id = cfg["tableIdForQuery"]

# 2. Build the URL dynamically
url = f"https://api.scb.se/OV0104/v1/doris/en/ssd/START/BE/BE0101/BE0101C/{table_id}"

headers = {"Content-Type": "application/json"}

# 3. Fetch the data
r = requests.post(url, json=payload, headers=headers)
r.raise_for_status()

# 4. Parse according to response format
fmt = payload.get("response", {}).get("format", "").lower()

# 5. Handle CSV response
if fmt == "csv":
    df = pd.read_csv(StringIO(r.text), sep=",")

    # Pick and rename columns appropriately
    df_selected = df.rename(columns={
        "region": "County",
        "Population density per sq. km 2024": "PopDensity_2024"
    })[["County", "PopDensity_2024"]]

    # Clean 'County' names
    df_selected["County"] = (
        df_selected["County"]
        .str.replace(r"^\d+\s+", "", regex=True)     # remove leading numbers
        .str.replace(r"\scounty$", "", regex=True, flags=re.IGNORECASE)   # remove "county" at end
        .str.strip()
    )

    # Ensure 'data/' directory exists
    data_dir = Path("data")
    data_dir.mkdir(parents=True, exist_ok=True)

    # Save the cleaned DataFrame
    output_filename = "popdensity.csv"
    out_csv = data_dir / output_filename
    df_selected.to_csv(out_csv, index=False)
    print(f"Data saved to {out_csv.resolve()}")

elif fmt == "px":
    data_dir = Path("data")
    data_dir.mkdir(parents=True, exist_ok=True)

    output_filename = f"{table_id}.px"
    out_px = data_dir / output_filename
    out_px.write_text(r.text, encoding="utf-8")
    print(f"PC-Axis file saved to {out_px.resolve()}")

else:
    print("Response format not recognized. Here's the raw text:")
    print(r.text)
