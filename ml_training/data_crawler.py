import requests
import pandas as pd
import xml.etree.ElementTree as ET
import os

def fetch_full_ssq_data():
    url = 'https://kaijiang.500.com/static/info/kaijiang/xml/ssq/list.xml'
    print(f"Fetching full dataset from {url}...")
    
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        root = ET.fromstring(response.content)
        data = []
        
        for row in root.findall('row'):
            expect = row.get('expect')
            opencode = row.get('opencode')
            opentime = row.get('opentime')
            
            if not expect or not opencode:
                continue
                
            parts = opencode.split('|')
            reds = parts[0].split(',')
            blue = parts[1]
            
            data.append({
                'issue': expect,
                'date': opentime,
                'red1': reds[0],
                'red2': reds[1],
                'red3': reds[2],
                'red4': reds[3],
                'red5': reds[4],
                'red6': reds[5],
                'blue': blue
            })
            
        df = pd.DataFrame(data)
        # Ensure issue is numeric for sorting
        df['issue'] = pd.to_numeric(df['issue'])
        df = df.sort_values('issue').reset_index(drop=True)
        
        df.to_csv('ssq_data.csv', index=False)
        print(f"Successfully saved {len(df)} records to ssq_data.csv")
        return df
        
    except Exception as e:
        print(f"Error fetching data: {e}")
        return None

if __name__ == "__main__":
    fetch_full_ssq_data()