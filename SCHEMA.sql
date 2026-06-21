DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS property_scores CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS sources CASCADE;

CREATE TABLE sources (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    base_url    TEXT NOT NULL,
    country     TEXT NOT NULL,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE properties (
    id          SERIAL PRIMARY KEY,
    source_id   INTEGER REFERENCES sources(id),

    zpid                              TEXT UNIQUE NOT NULL,
    status_type                       TEXT,
    status_text                       TEXT,
    raw_home_status_cd                TEXT,
    marketing_status_simplified_cd    TEXT,
    home_status_for_hdp               TEXT,

    address              TEXT,
    street_address       TEXT,
    city                 TEXT,
    state                TEXT,
    zip_code             TEXT,
    country              TEXT DEFAULT 'USA',
    latitude             NUMERIC(9,6),
    longitude            NUMERIC(9,6),
    is_unmappable        BOOLEAN DEFAULT false,

    price                NUMERIC(12,2),
    zestimate            NUMERIC(12,2),
    price_change         NUMERIC(6,2),
    days_on_zillow       INTEGER,
    tax_assessed_value   NUMERIC(10,2),
    rent_zestimate       NUMERIC(5,2),

    bedrooms             INTEGER,
    bathrooms            NUMERIC(4,1),
    lot_area_value       NUMERIC(8,2),
    living_area          NUMERIC(12,2),

    home_type            TEXT,

    detail_url           TEXT,
    img_src              TEXT[],
    availability_date    TIMESTAMPTZ,
    broker_name          TEXT,
    last_scraped_at      TIMESTAMPTZ DEFAULT NOW(),
    created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE property_scores (
    id                      SERIAL PRIMARY KEY,
    property_id             INTEGER REFERENCES properties(id) ON DELETE CASCADE,
    zpid                    TEXT NOT NULL,

    deal_score              NUMERIC(4,1),
    deal_rating             TEXT,
    ai_summary              TEXT,

    location_score          NUMERIC(4,1),
    financial_score         NUMERIC(4,1),
    condition_score         NUMERIC(4,1),
    feature_score           NUMERIC(4,1),
    market_timing_score     NUMERIC(4,1),

    location_reasoning      TEXT,
    financial_reasoning     TEXT,
    condition_reasoning     TEXT,
    feature_reasoning       TEXT,
    market_timing_reasoning TEXT,

    deal_breakers           TEXT[],
    deal_boosters           TEXT[],

    model_used              TEXT DEFAULT 'claude-sonnet-4-20250514',
    scored_at               TIMESTAMPTZ DEFAULT NOW(),
    score_version           INTEGER DEFAULT 1
);

CREATE TABLE alerts (
    id                       SERIAL PRIMARY KEY,
    property_id              INTEGER REFERENCES properties(id) ON DELETE CASCADE,
    zpid                     TEXT NOT NULL,
    trigger_reason           TEXT,
    deal_score               NUMERIC(4,1),
    channel                  TEXT,
    recipient                TEXT,
    message_sent             TEXT,
    delivered                BOOLEAN DEFAULT false,
    delivered_at             TIMESTAMPTZ,
    error_message            TEXT,
    created_at               TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_properties_zpid        ON properties(zpid);
CREATE INDEX idx_properties_city        ON properties(city);
CREATE INDEX idx_properties_price       ON properties(price);
CREATE INDEX idx_property_scores_deal   ON property_scores(deal_score DESC);
CREATE INDEX idx_alerts_channel         ON alerts(channel);