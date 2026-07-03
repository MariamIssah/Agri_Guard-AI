"""
Neon PostgreSQL database layer for AgriGuard AI.
Handles users, harvest submissions, farm diary, and admin queries.
"""

import os
import hashlib
import contextlib
import threading
import psycopg2
from psycopg2.extras import RealDictCursor

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
except ImportError:
    pass

DATABASE_URL = os.getenv('DATABASE_URL', '')

# One persistent connection per thread (uvicorn worker threads reuse their connection)
_local = threading.local()


def _new_conn() -> psycopg2.extensions.connection:
    if not DATABASE_URL:
        raise RuntimeError('DATABASE_URL is not set. Add it to your .env file.')
    # Short per-attempt timeout — callers retry externally
    return psycopg2.connect(dsn=DATABASE_URL, connect_timeout=15)


def _live_conn() -> psycopg2.extensions.connection:
    """Return the thread-local connection, reconnecting if it dropped."""
    conn = getattr(_local, 'conn', None)
    if conn is None or conn.closed:
        _local.conn = _new_conn()
    else:
        try:
            conn.cursor().execute('SELECT 1')
            conn.rollback()  # reset any open transaction state
        except Exception:
            try:
                conn.close()
            except Exception:
                pass
            _local.conn = _new_conn()
    return _local.conn


@contextlib.contextmanager
def get_conn():
    """Yield the thread-local connection. Reconnects automatically if Neon dropped it."""
    conn = _live_conn()
    try:
        yield conn
        conn.commit()
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        # Mark broken so next call reconnects
        try:
            conn.close()
        except Exception:
            pass
        _local.conn = None
        raise


def _hash(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


# ── Schema ─────────────────────────────────────────────────────────────────────

_SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    phone         TEXT,
    role          TEXT NOT NULL DEFAULT 'farmer',
    region        TEXT,
    district      TEXT,
    farm_size_ha  FLOAT,
    password_hash TEXT NOT NULL,
    hidden        BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS harvest_submissions (
    id                     SERIAL PRIMARY KEY,
    farmer_id              TEXT,
    crop                   TEXT    NOT NULL,
    region                 TEXT    NOT NULL,
    district               TEXT,
    town                   TEXT,
    phone                  TEXT,
    area_hectares          FLOAT   NOT NULL,
    actual_yield_kg        FLOAT   NOT NULL,
    actual_yield_kg_per_ha FLOAT,
    quantity_available_kg  FLOAT,
    price_per_kg_ghs       FLOAT,
    quality_score          FLOAT,
    notes                  TEXT,
    year                   INT,
    hidden                 BOOLEAN DEFAULT FALSE,
    submitted_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS farm_diary (
    id                   SERIAL PRIMARY KEY,
    farmer_id            TEXT NOT NULL,
    crop                 TEXT NOT NULL,
    region               TEXT NOT NULL,
    district             TEXT,
    planting_date        DATE,
    record_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    growth_stage         TEXT,
    temp_min_c           FLOAT,
    temp_max_c           FLOAT,
    rainfall_mm          FLOAT,
    fertilizer_applied   BOOLEAN DEFAULT FALSE,
    fertilizer_type      TEXT,
    fertilizer_kg_ha     FLOAT,
    pest_observed        BOOLEAN DEFAULT FALSE,
    pest_description     TEXT,
    disease_observed     BOOLEAN DEFAULT FALSE,
    disease_description  TEXT,
    irrigation_applied   BOOLEAN DEFAULT FALSE,
    notes                TEXT,
    hidden               BOOLEAN DEFAULT FALSE,
    submitted_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS buyer_activity (
    id          SERIAL PRIMARY KEY,
    buyer_id    TEXT NOT NULL,
    action      TEXT NOT NULL,   -- 'browse', 'search', 'select'
    screen      TEXT,            -- 'produce_availability', 'regional_forecast', 'search'
    crop        TEXT,
    region      TEXT,
    district    TEXT,
    item_id     TEXT,            -- submitted_at of the selected harvest submission
    query       TEXT,            -- raw search text if any
    details     JSONB,           -- any extra context as JSON
    logged_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email  ON users(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_hs_farmer    ON harvest_submissions(farmer_id);
CREATE INDEX IF NOT EXISTS idx_hs_crop      ON harvest_submissions(LOWER(crop));
CREATE INDEX IF NOT EXISTS idx_hs_region    ON harvest_submissions(LOWER(region));
CREATE INDEX IF NOT EXISTS idx_hs_year      ON harvest_submissions(year);
CREATE INDEX IF NOT EXISTS idx_fd_farmer    ON farm_diary(farmer_id);
CREATE INDEX IF NOT EXISTS idx_fd_crop      ON farm_diary(LOWER(crop));
CREATE INDEX IF NOT EXISTS idx_fd_region    ON farm_diary(LOWER(region));
CREATE INDEX IF NOT EXISTS idx_fd_date      ON farm_diary(record_date);
CREATE INDEX IF NOT EXISTS idx_ba_buyer     ON buyer_activity(buyer_id);
CREATE INDEX IF NOT EXISTS idx_ba_action    ON buyer_activity(action);
CREATE INDEX IF NOT EXISTS idx_ba_logged    ON buyer_activity(logged_at DESC);

CREATE TABLE IF NOT EXISTS crop_config (
    crop_name        TEXT PRIMARY KEY,
    gdd_to_harvest   INT,
    base_temp_c      FLOAT NOT NULL DEFAULT 10.0,
    typical_area_ha  FLOAT NOT NULL DEFAULT 2.3,
    active           BOOLEAN NOT NULL DEFAULT TRUE
);
"""

_DEFAULT_CROPS = [
    ('Maize',     1200, 10.0, 2.3),
    ('Rice',      1400, 10.0, 3.5),
    ('Tomato',     900, 10.0, 1.2),
    ('Pepper',    1100, 10.0, 1.0),
    ('Cassava',   3000, 10.0, 2.0),
    ('Yam',       2500, 10.0, 1.8),
    ('Groundnut', 1300, 10.0, 2.0),
    ('Soybean',   1300, 10.0, 2.0),
    ('Cowpea',    1000, 10.0, 1.5),
    ('Millet',    1000, 10.0, 3.0),
    ('Sorghum',   1200, 10.0, 2.5),
    ('Cocoa',     None, 10.0, 4.0),
    ('Plantain',  None, 10.0, 1.5),
]


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(_SCHEMA)
            # Seed crop config only if table is empty
            cur.execute('SELECT COUNT(*) FROM crop_config')
            if cur.fetchone()[0] == 0:
                cur.executemany(
                    """INSERT INTO crop_config (crop_name, gdd_to_harvest, base_temp_c, typical_area_ha)
                       VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING""",
                    _DEFAULT_CROPS,
                )
                print(f'[DB] Seeded {len(_DEFAULT_CROPS)} crops into crop_config.')
        conn.commit()
    print('[DB] Tables ready.')


# ── Crop config ────────────────────────────────────────────────────────────────

def get_crop_list() -> list[str]:
    """Return names of all active crops, ordered alphabetically."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT crop_name FROM crop_config WHERE active=TRUE ORDER BY crop_name'
            )
            return [r[0] for r in cur.fetchall()]


def get_gdd_config() -> dict:
    """Return {crop_name: gdd_to_harvest} for all active crops that have a GDD value."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT crop_name, gdd_to_harvest FROM crop_config WHERE active=TRUE AND gdd_to_harvest IS NOT NULL'
            )
            return {r[0]: r[1] for r in cur.fetchall()}


def get_crop_areas() -> dict:
    """Return {crop_name: typical_area_ha} for all active crops."""
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT crop_name, typical_area_ha FROM crop_config WHERE active=TRUE'
            )
            return {r[0]: r[1] for r in cur.fetchall()}


def upsert_crop(crop_name: str, gdd_to_harvest: int | None,
                base_temp_c: float, typical_area_ha: float) -> dict:
    sql = """
        INSERT INTO crop_config (crop_name, gdd_to_harvest, base_temp_c, typical_area_ha, active)
        VALUES (%s, %s, %s, %s, TRUE)
        ON CONFLICT (crop_name) DO UPDATE
            SET gdd_to_harvest  = EXCLUDED.gdd_to_harvest,
                base_temp_c     = EXCLUDED.base_temp_c,
                typical_area_ha = EXCLUDED.typical_area_ha,
                active          = TRUE
        RETURNING crop_name, gdd_to_harvest, base_temp_c, typical_area_ha, active
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (crop_name, gdd_to_harvest, base_temp_c, typical_area_ha))
            row = cur.fetchone()
        conn.commit()
    return dict(row)


def deactivate_crop(crop_name: str) -> bool:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                'UPDATE crop_config SET active=FALSE WHERE crop_name=%s', (crop_name,)
            )
            updated = cur.rowcount
        conn.commit()
    return updated > 0


def all_crops_config() -> list[dict]:
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute('SELECT * FROM crop_config ORDER BY crop_name')
            return [dict(r) for r in cur.fetchall()]


# ── Auth ───────────────────────────────────────────────────────────────────────

def create_user(rec: dict) -> dict:
    """Register a new user. Raises ValueError if email already taken."""
    sql = """
        INSERT INTO users (id, name, email, phone, role, region, district, farm_size_ha, password_hash)
        VALUES (%(id)s, %(name)s, %(email)s, %(phone)s, %(role)s,
                %(region)s, %(district)s, %(farm_size_ha)s, %(password_hash)s)
        RETURNING id, name, email, phone, role, region, district, farm_size_ha, created_at
    """
    data = {**rec, 'password_hash': _hash(rec['password'])}
    data.pop('password', None)
    try:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, data)
                row = dict(cur.fetchone())
            conn.commit()
        return row
    except psycopg2.errors.UniqueViolation:
        raise ValueError('An account with this email already exists.')


def find_user_by_email(email: str, password: str) -> dict | None:
    """Return user dict if credentials match, None otherwise."""
    sql = """
        SELECT id, name, email, phone, role, region, district, farm_size_ha
        FROM users
        WHERE LOWER(email) = LOWER(%s)
          AND password_hash = %s
          AND hidden = FALSE
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (email, _hash(password)))
            row = cur.fetchone()
    return dict(row) if row else None


def soft_delete_user(user_id: str) -> bool:
    """Hide the user and ALL their data. Data stays for retraining."""
    sqls = [
        "UPDATE users SET hidden = TRUE WHERE id = %s",
        "UPDATE harvest_submissions SET hidden = TRUE WHERE farmer_id = %s",
        "UPDATE farm_diary SET hidden = TRUE WHERE farmer_id = %s",
    ]
    with get_conn() as conn:
        with conn.cursor() as cur:
            for sql in sqls:
                cur.execute(sql, (user_id,))
            updated = cur.rowcount
        conn.commit()
    return updated >= 0


# ── Harvest Submissions ────────────────────────────────────────────────────────

def insert_submission(rec: dict) -> dict:
    sql = """
        INSERT INTO harvest_submissions
            (farmer_id, crop, region, district, town, phone,
             area_hectares, actual_yield_kg, actual_yield_kg_per_ha,
             quantity_available_kg, price_per_kg_ghs,
             quality_score, notes, year)
        VALUES
            (%(farmer_id)s, %(crop)s, %(region)s, %(district)s, %(town)s, %(phone)s,
             %(area_hectares)s, %(actual_yield_kg)s, %(actual_yield_kg_per_ha)s,
             %(quantity_available_kg)s, %(price_per_kg_ghs)s,
             %(quality_score)s, %(notes)s, %(year)s)
        RETURNING id, submitted_at
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, rec)
            row = cur.fetchone()
        conn.commit()
    rec['id'] = row['id']
    rec['submitted_at'] = row['submitted_at'].isoformat()
    return rec


def hide_submission(farmer_id: str, submitted_at: str) -> bool:
    prefix = submitted_at[:19] + '%'
    sql = """
        UPDATE harvest_submissions SET hidden = TRUE
        WHERE farmer_id = %s AND submitted_at::text LIKE %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (farmer_id, prefix))
            updated = cur.rowcount
        conn.commit()
    return updated > 0


def query_actuals(crop=None, region=None, district=None, year=None) -> list[dict]:
    conditions = ['hidden = FALSE']
    params: list = []
    if crop:
        conditions.append('LOWER(crop) = LOWER(%s)'); params.append(crop)
    if region:
        conditions.append('LOWER(region) = LOWER(%s)'); params.append(region)
    if district:
        conditions.append('LOWER(district) = LOWER(%s)'); params.append(district)
    if year:
        conditions.append('year = %s'); params.append(year)
    sql = f"SELECT * FROM harvest_submissions WHERE {' AND '.join(conditions)} ORDER BY submitted_at DESC"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def query_my_submissions(farmer_id: str) -> list[dict]:
    sql = "SELECT * FROM harvest_submissions WHERE farmer_id=%s AND hidden=FALSE ORDER BY submitted_at DESC"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (farmer_id,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def query_all_for_training() -> list[dict]:
    """All submissions including hidden — for model retraining only."""
    sql = "SELECT * FROM harvest_submissions ORDER BY submitted_at"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


# ── Farm Diary ─────────────────────────────────────────────────────────────────

def insert_diary_entry(rec: dict) -> dict:
    sql = """
        INSERT INTO farm_diary
            (farmer_id, crop, region, district, planting_date, record_date,
             growth_stage, temp_min_c, temp_max_c, rainfall_mm,
             fertilizer_applied, fertilizer_type, fertilizer_kg_ha,
             pest_observed, pest_description,
             disease_observed, disease_description,
             irrigation_applied, notes)
        VALUES
            (%(farmer_id)s, %(crop)s, %(region)s, %(district)s,
             %(planting_date)s, %(record_date)s, %(growth_stage)s,
             %(temp_min_c)s, %(temp_max_c)s, %(rainfall_mm)s,
             %(fertilizer_applied)s, %(fertilizer_type)s, %(fertilizer_kg_ha)s,
             %(pest_observed)s, %(pest_description)s,
             %(disease_observed)s, %(disease_description)s,
             %(irrigation_applied)s, %(notes)s)
        RETURNING id, submitted_at
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, rec)
            row = cur.fetchone()
        conn.commit()
    rec['id'] = row['id']
    rec['submitted_at'] = row['submitted_at'].isoformat()
    return rec


def query_my_diary(farmer_id: str) -> list[dict]:
    sql = """
        SELECT * FROM farm_diary WHERE farmer_id=%s AND hidden=FALSE
        ORDER BY record_date DESC, submitted_at DESC
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (farmer_id,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def query_diary_for_season(farmer_id: str, crop: str, planting_date: str) -> list[dict]:
    """All diary entries for a specific crop season — used for in-season yield prediction."""
    sql = """
        SELECT * FROM farm_diary
        WHERE farmer_id=%s AND LOWER(crop)=LOWER(%s)
          AND planting_date=%s AND hidden=FALSE
        ORDER BY record_date
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (farmer_id, crop, planting_date))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def hide_diary_entry(farmer_id: str, entry_id: int) -> bool:
    sql = "UPDATE farm_diary SET hidden=TRUE WHERE id=%s AND farmer_id=%s"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (entry_id, farmer_id))
            updated = cur.rowcount
        conn.commit()
    return updated > 0


def query_all_diary_for_training() -> list[dict]:
    """All diary entries including hidden — for retraining pipeline."""
    sql = "SELECT * FROM farm_diary ORDER BY record_date, submitted_at"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


# ── Admin Queries ──────────────────────────────────────────────────────────────

def admin_stats() -> dict:
    sql = """
        SELECT
            (SELECT COUNT(*) FROM users WHERE hidden=FALSE)                        AS total_users,
            (SELECT COUNT(*) FROM users WHERE role='farmer' AND hidden=FALSE)      AS total_farmers,
            (SELECT COUNT(*) FROM users WHERE role='buyer'  AND hidden=FALSE)      AS total_buyers,
            (SELECT COUNT(*) FROM users WHERE hidden=TRUE)                         AS deleted_users,
            (SELECT COUNT(*) FROM harvest_submissions WHERE hidden=FALSE)          AS total_submissions,
            (SELECT COUNT(*) FROM harvest_submissions WHERE hidden=TRUE)           AS hidden_submissions,
            (SELECT COUNT(*) FROM farm_diary WHERE hidden=FALSE)                   AS total_diary_entries,
            (SELECT COUNT(*) FROM farm_diary  WHERE record_date=CURRENT_DATE)     AS diary_entries_today,
            (SELECT COUNT(DISTINCT farmer_id) FROM harvest_submissions)            AS active_farmers,
            (SELECT COUNT(DISTINCT crop) FROM harvest_submissions WHERE hidden=FALSE) AS unique_crops
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            row = cur.fetchone()
    return {k: int(v or 0) for k, v in dict(row).items()}


def admin_all_users(include_deleted=True) -> list[dict]:
    where = '' if include_deleted else 'WHERE hidden=FALSE'
    sql = f"SELECT id,name,email,phone,role,region,district,farm_size_ha,hidden,created_at FROM users {where} ORDER BY created_at DESC"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def admin_all_submissions(include_hidden=True) -> list[dict]:
    where = '' if include_hidden else 'WHERE hidden=FALSE'
    sql = f"SELECT * FROM harvest_submissions {where} ORDER BY submitted_at DESC LIMIT 500"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def admin_all_diary(include_hidden=True) -> list[dict]:
    where = '' if include_hidden else 'WHERE hidden=FALSE'
    sql = f"SELECT * FROM farm_diary {where} ORDER BY record_date DESC, submitted_at DESC LIMIT 500"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
    return [dict(r) for r in rows]


# ── Buyer Activity ─────────────────────────────────────────────────────────────

def log_buyer_activity(rec: dict) -> None:
    import json as _json
    details = rec.get('details')
    if isinstance(details, dict):
        details = _json.dumps(details)
    sql = """
        INSERT INTO buyer_activity
            (buyer_id, action, screen, crop, region, district, item_id, query, details)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (
                rec.get('buyer_id'), rec.get('action'), rec.get('screen'),
                rec.get('crop'), rec.get('region'), rec.get('district'),
                rec.get('item_id'), rec.get('query'), details,
            ))
        conn.commit()


def admin_buyer_activity(limit: int = 500) -> list[dict]:
    sql = """
        SELECT * FROM buyer_activity
        ORDER BY logged_at DESC
        LIMIT %s
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (limit,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def admin_buyer_stats() -> dict:
    sql = """
        SELECT
            (SELECT COUNT(*) FROM buyer_activity)                           AS total_actions,
            (SELECT COUNT(DISTINCT buyer_id) FROM buyer_activity)          AS unique_buyers,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='search')    AS total_searches,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='select')    AS total_selects,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='browse')    AS total_browses,
            (SELECT COUNT(*) FROM buyer_activity
             WHERE logged_at >= NOW() - INTERVAL '24 hours')               AS actions_today,
            (SELECT crop FROM buyer_activity
             WHERE crop IS NOT NULL
             GROUP BY crop ORDER BY COUNT(*) DESC LIMIT 1)                 AS top_crop,
            (SELECT region FROM buyer_activity
             WHERE region IS NOT NULL
             GROUP BY region ORDER BY COUNT(*) DESC LIMIT 1)               AS top_region
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            row = cur.fetchone()
    return dict(row) if row else {}


# ── Buyer Activity ─────────────────────────────────────────────────────────────

def log_buyer_activity(rec: dict) -> None:
    import json as _json
    details = rec.get('details')
    if isinstance(details, dict):
        details = _json.dumps(details)
    sql = """
        INSERT INTO buyer_activity
            (buyer_id, action, screen, crop, region, district, item_id, query, details)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (
                rec.get('buyer_id'), rec.get('action'), rec.get('screen'),
                rec.get('crop'), rec.get('region'), rec.get('district'),
                rec.get('item_id'), rec.get('query'), details,
            ))
        conn.commit()


def admin_buyer_activity(limit: int = 500) -> list[dict]:
    sql = "SELECT * FROM buyer_activity ORDER BY logged_at DESC LIMIT %s"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (limit,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def query_my_activity(buyer_id: str) -> list[dict]:
    sql = "SELECT * FROM buyer_activity WHERE buyer_id=%s ORDER BY logged_at DESC LIMIT 200"
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (buyer_id,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


def delete_activity_entry(buyer_id: str, entry_id: int) -> bool:
    sql = "DELETE FROM buyer_activity WHERE id=%s AND buyer_id=%s"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (entry_id, buyer_id))
            deleted = cur.rowcount
        conn.commit()
    return deleted > 0


def clear_my_activity(buyer_id: str) -> int:
    sql = "DELETE FROM buyer_activity WHERE buyer_id=%s"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (buyer_id,))
            deleted = cur.rowcount
        conn.commit()
    return deleted


def update_user_profile(user_id: str, fields: dict) -> dict | None:
    allowed = {'name', 'phone', 'region', 'district'}
    updates = {k: v for k, v in fields.items() if k in allowed and v is not None}
    _select = ("SELECT id, name, email, phone, role, region, district, farm_size_ha "
               "FROM users WHERE id=%s AND hidden=FALSE")
    if not updates:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(_select, (user_id,))
                row = cur.fetchone()
        return dict(row) if row else None
    set_clause = ', '.join(f'{k}=%s' for k in updates)
    sql = f"""
        UPDATE users SET {set_clause}
        WHERE id=%s AND hidden=FALSE
        RETURNING id, name, email, phone, role, region, district, farm_size_ha
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, (*updates.values(), user_id))
            row = cur.fetchone()
        conn.commit()
    return dict(row) if row else None


def admin_buyer_stats() -> dict:
    sql = """
        SELECT
            (SELECT COUNT(*) FROM buyer_activity)                                    AS total_actions,
            (SELECT COUNT(DISTINCT buyer_id) FROM buyer_activity)                   AS unique_buyers,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='search')             AS total_searches,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='select')             AS total_selects,
            (SELECT COUNT(*) FROM buyer_activity WHERE action='browse')             AS total_browses,
            (SELECT COUNT(*) FROM buyer_activity
             WHERE logged_at >= NOW() - INTERVAL '24 hours')                        AS actions_today,
            (SELECT crop   FROM buyer_activity WHERE crop   IS NOT NULL
             GROUP BY crop   ORDER BY COUNT(*) DESC LIMIT 1)                        AS top_crop,
            (SELECT region FROM buyer_activity WHERE region IS NOT NULL
             GROUP BY region ORDER BY COUNT(*) DESC LIMIT 1)                        AS top_region
    """
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            row = cur.fetchone()
    return dict(row) if row else {}


# ── Migration helper ───────────────────────────────────────────────────────────

def migrate_from_json(json_path: str) -> int:
    import json as _json
    if not os.path.exists(json_path):
        return 0
    with open(json_path) as f:
        records = _json.load(f)
    inserted = 0
    for rec in records:
        submitted_at = rec.get('submitted_at', '')
        prefix = submitted_at[:19] + '%'
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT 1 FROM harvest_submissions WHERE farmer_id IS NOT DISTINCT FROM %s AND submitted_at::text LIKE %s LIMIT 1",
                    (rec.get('farmer_id'), prefix))
                exists = cur.fetchone() is not None
        if not exists:
            try:
                insert_submission({
                    'farmer_id': rec.get('farmer_id'), 'crop': rec.get('crop', ''),
                    'region': rec.get('region', ''), 'district': rec.get('district'),
                    'town': rec.get('town'), 'phone': rec.get('phone'),
                    'area_hectares': rec.get('area_hectares', 0),
                    'actual_yield_kg': rec.get('actual_yield_kg', 0),
                    'actual_yield_kg_per_ha': rec.get('actual_yield_kg_per_ha'),
                    'quantity_available_kg': rec.get('quantity_available_kg'),
                    'price_per_kg_ghs': rec.get('price_per_kg_ghs'),
                    'quality_score': rec.get('quality_score'),
                    'notes': rec.get('notes'), 'year': rec.get('year'),
                })
                inserted += 1
            except Exception as e:
                print(f'[WARN] Could not migrate record: {e}')
    return inserted
