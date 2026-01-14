import requests
import pandas as pd
from bs4 import BeautifulSoup
from requests.packages.urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)


def fetch_ssq_data(page_size=500):
    url = 'https://datachart.500.com/ssq/history/newinc/history.php'
    params = {'limit': page_size}
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                      'AppleWebKit/537.36 (KHTML, like Gecko) '
                      'Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': 'https://datachart.500.com/ssq/',
    }

    response = requests.get(
        url,
        params=params,
        headers=headers,
        timeout=30,
        verify=False,
    )
    if not response.ok:
        snippet = response.text[:500]
        raise RuntimeError(
            f'HTTP {response.status_code} {response.reason}; '
            f'Content-Type={response.headers.get("Content-Type")}; '
            f'Body={snippet}'
        )

    response.encoding = response.apparent_encoding
    soup = BeautifulSoup(response.text, 'html.parser')
    rows = soup.select('#tdata tr')

    results = []
    for row in rows:
        cells = [td.get_text(strip=True) for td in row.find_all('td')]
        if len(cells) < 8:
            continue
        issue = cells[0]
        if not issue.isdigit():
            continue
        red_balls = [int(x) for x in cells[1:7]]
        blue_ball = int(cells[7])
        draw_date = cells[-1]
        results.append({
            'issue': issue,
            'date': draw_date,
            'red1': red_balls[0],
            'red2': red_balls[1],
            'red3': red_balls[2],
            'red4': red_balls[3],
            'red5': red_balls[4],
            'red6': red_balls[5],
            'blue': blue_ball,
        })

    if not results:
        raise RuntimeError('No results parsed from HTML response.')

    return pd.DataFrame(results)


if __name__ == '__main__':
    df = fetch_ssq_data()
    df.to_csv('ssq_data.csv', index=False)
    print(f'Saved {len(df)} records to ssq_data.csv')
