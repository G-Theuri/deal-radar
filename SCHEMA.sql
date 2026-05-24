
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
    zpid        TEXT UNIQUE NOT NULL,
    source_id   INTEGER REFERENCES sources(id),

    -- location
    address         TEXT,
    city            TEXT,
    state           TEXT,
    zip_code        TEXT,
    country         TEXT DEFAULT 'US',
    latitude        NUMERIC(9,6),
    longitude       NUMERIC(9,6),
    neighbourhood   TEXT,
    walk_score      INTEGER,
    transit_score   INTEGER,
    school_rating   NUMERIC(3,1)

    --Financials
    listing_price               NUMERIC(12,2)
    price_per_sqft              NUMERIC(8,2),
    zestimate                   NUMERIC(12,2),
    price_vs_zestimate_pct      NUMERIC(6,2),
    price_reduced               BOOLEAN DEFAULT false,
    original_price              NUMERIC(12,2),
    days_on_market              INTEGER,
    hoa_fee                     NUMERIC(8,2),
    property_tax_annual         NUMERIC(10,2),
    estimated_rental_yield      NUMERIC(5,2),

    -- Physical
    bedrooms            INTEGER,
    bathrooms           NUMERIC(4,1),
    square_footage      INTEGER,
    lot_size_sqft       INTEGER,
    year_built          INTEGER,
    garage              BOOLEAN,
    basement            BOOLEAN,
    pool                BOOLEAN,
    stories             INTEGER,

    -- Condition & Features
    property_type           TEXT,  -- 'single_family','condo','townhouse'
    listing_status          TEXT,  -- 'active','pending','sold'
    condition               TEXT, -- 'excellent','good','fair','poor'
    open_kitchen            BOOLEAN,
    recently_renovated      BOOLEAN,
    move_in_ready           BOOLEAN,
    appliances_included     BOOLEAN,

    -- Deals Signals
    description TEXT, -- full raw listing description
    keywords_found TEXT[], -- ['motivated seller','price reduced']
    price_drop_count INTEGER DEFAULT 0,
    tax_assessed_value NUMERIC(12, 2),
    price_vs_assessed_pct NUMERIC(6, 2), -- % above or below tax assessment

    --Metadata
    listing_url  TEXT,
    image_urls TEXT[],
    last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

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