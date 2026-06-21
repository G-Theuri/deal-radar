
-- TABLE 1: sources
-- Tracks where we scrape from.
-- When you add Redfin or Rightmove later, just add a row here.

CREATE TABLE sources (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,          -- 'Zillow', 'Redfin'
    base_url    TEXT NOT NULL,          -- 'https://www.zillow.com'
    country     TEXT NOT NULL,          -- 'US', 'UK'
    is_active   BOOLEAN DEFAULT true,   -- flip to false to pause a source
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE properties(
    id          SERIAL PRIMARY KEY,
    source_id   INTEGER REFERENCES sources(id),

    -- identifiers
    zpid                            TEXT UNIQUE NOT NULL,
    status_type                     TEXT,
    status_text                     TEXT,
    rawHomeStatusCd                 TEXT,
    marketingStatusSimplifiedCd     TEXT,
    homeStatusForHDP                TEXT,



    address         TEXT,
    streetAddress   TEXT,
    city            TEXT,
    state           TEXT,
    zip_code        TEXT,
    country         TEXT DEFAULT 'USA',
    latitude        NUMERIC(9,6),
    longitude       NUMERIC(9,6),
    isUnmappable   BOOLEAN DEFAULT false,

    --Financials
    price                       NUMERIC(12,2)
    zestimate                   NUMERIC(12,2),
    priceChange                 NUMERIC(6,2),
    daysOnZillow                INTEGER,
    taxAssessedValue            NUMERIC(10,2),
    rentZestimate               NUMERIC(5,2),

    -- Physical
    bedrooms            INTEGER,
    bathrooms           NUMERIC(4,1),
    lotAreaValue        NUMERIC(8,2),
    livingArea          NUMERIC(12,2),

    -- Condition & Features
    homeType           TEXT,  -- 'single_family','condo','townhouse'

    --Metadata
    detailUrl                      TEXT,
    imgSrc                          TEXT[],
    availabilityDate                TIMESTAMPTZ,
    brokerName                      TEXT,
    last_scraped_at                 TIMESTAMPTZ DEFAULT NOW(),
    created_at                      TIMESTAMPTZ DEFAULT NOW(),

);

CREATE TABLE property_scores(
    id                      SERIAL PRIMARY KEY,
    property_id             INTEGER REFERENCES properties(id) ON DELETE CASCADE,
    zpid                    TEXT NOT NULL,          -- denormalized for fast lookups

    -- Overall
    deal_score              NUMERIC(4,1),           -- 0.0 to 10.0
    deal_rating             TEXT,                   -- 'hot','good','fair','pass'
    ai_summary              TEXT,                   -- one paragraph AI verdict

    -- Category scores (all 0.0 to 10.0)
    location_score          NUMERIC(4,1),
    financial_score         NUMERIC(4,1),
    condition_score         NUMERIC(4,1),
    feature_score           NUMERIC(4,1),
    market_timing_score     NUMERIC(4,1),           -- days on market, price drops

    -- AI reasoning per category
    location_reasoning      TEXT,
    financial_reasoning     TEXT,
    condition_reasoning     TEXT,
    feature_reasoning       TEXT,
    market_timing_reasoning TEXT,

    -- Deal breakers and boosters
    deal_breakers           TEXT[],                 -- ['no garage','HOA too high']
    deal_boosters           TEXT[],                 -- ['open kitchen','price reduced 3x']

    -- AI metadata
    model_used              TEXT DEFAULT 'claude-sonnet-4-20250514',
    scored_at               TIMESTAMPTZ DEFAULT NOW(),
    score_version           INTEGER DEFAULT 1       -- increment when scoring logic changes
);

CREATE TABLE alerts(
    id SERIAL PRIMARY KEY
    property_id             INTEGER REFERENCES properties(id) ON DELETE CASCADE,
    zpid                    TEXT NOT NULL,
    trigger_reason          TEXT,                   -- 'score above 8','price drop','new listing'
    deal_score              NUMERIC(4,1),           -- score at time of alert
    channel                 TEXT,                   -- 'discord','telegram','whatsapp'
    recipient               TEXT,                   -- channel ID or phone number
    message_sent            TEXT,                   -- exact message that was fired
    delivered               BOOLEAN DEFAULT false,
    delivered_at            TIMESTAMPTZ,
    error_message           TEXT,                   -- if delivery failed, why
    created_at              TIMESTAMPTZ DEFAULT NOW()
)


-- INDEXES

CREATE INDEX idx_properties_zpid        ON properties(zpid);
CREATE INDEX idx_properties_city        ON properties(city);
CREATE INDEX idx_properties_price       ON properties(listing_price);
CREATE INDEX idx_property_scores_deal   ON property_scores(deal_score DESC);
CREATE INDEX idx_alerts_channel         ON alerts(channel);