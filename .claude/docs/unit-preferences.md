# Unit Preferences

## Currency

Always express monetary amounts in **USD ($)**. When a source gives a price in another currency, convert to USD before presenting it.

**How to convert — use bash, not mental math:**

```bash
# Get the USD value of 1 unit of a foreign currency (e.g. SGD → USD)
curl -s "https://api.exchangerate-api.com/v4/latest/SGD" | jq '.rates.USD'

# Then multiply: amount_in_foreign * rate = USD
echo "295 * $(curl -s https://api.exchangerate-api.com/v4/latest/SGD | jq '.rates.USD')" | bc
```

Always note the conversion date when presenting converted prices (rates fluctuate).

Round to the nearest dollar for whole-item prices; two decimal places for per-unit costs.

## Currency Disambiguation

Currency symbols and names can be ambiguous — resolve before fetching a rate:

| Ambiguous input | Ask / resolve to |
|---|---|
| `¥` | Could be JPY (Japanese yen) or CNY (Chinese yuan renminbi). Infer from context (Japanese product → JPY; Chinese store/AliExpress → CNY). When unclear, ask. |
| `$` without qualifier | Assume USD if context is US-based; otherwise resolve from context (AUD, CAD, SGD, HKD, etc.) |
| `"dollar"` | As above — check context for country |
| `"pound"` | Usually GBP; could be EGP, LBP, etc. in regional context |
| `"franc"` | CHF most common; CFP franc (XPF) in French Polynesia |
| `"krona"` / `"krone"` | SEK (Sweden), NOK (Norway), DKK (Denmark), ISK (Iceland) — resolve from context |

When context is genuinely ambiguous, ask before converting.

## ISO 4217 codes for the exchangerate-api

Use ISO 4217 three-letter codes as the base currency in the API URL:
`https://api.exchangerate-api.com/v4/latest/<CODE>`

Common codes: `SGD`, `EUR`, `GBP`, `JPY`, `CNY`, `AUD`, `CAD`, `CHF`, `KRW`, `HKD`.
