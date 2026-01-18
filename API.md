# API and CLI Guide

## Run with Docker Compose

```bash
cp .env.example .env
# edit .env and set POSTGRES_PASSWORD
docker compose up --build
```

API will be available at `http://localhost:8000`.
The `tests` service runs `pytest` automatically during startup and then exits.
If you want the stack to stop when tests finish, run:
```bash
docker compose up --build --abort-on-container-exit --exit-code-from tests
```

## Run locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/inventory
uvicorn app.main:app --reload
```

## API Spec

### Create server
`POST /servers`

Request:
```json
{"hostname":"srv-1","ip_address":"10.0.0.1","state":"active"}
```

Responses:
- `201` server object
- `400` hostname must be unique or invalid payload

### List servers
`GET /servers`

Responses:
- `200` list of server objects

### Get server
`GET /servers/{id}`

Responses:
- `200` server object
- `404` not found

### Update server
`PUT /servers/{id}`

Request:
```json
{"hostname":"srv-1","ip_address":"10.0.0.2","state":"offline"}
```

Responses:
- `200` server object
- `400` hostname must be unique or invalid payload
- `404` not found

### Delete server
`DELETE /servers/{id}`

Responses:
- `204` deleted
- `404` not found

## CLI Spec

The CLI talks to the API. Set `API_URL` if needed (default `http://localhost:8000`).

```bash
python -m cli list
python -m cli get 1
python -m cli create srv-1 10.0.0.1 active
python -m cli update 1 srv-1b 10.0.0.2 offline
python -m cli delete 1
```

## Tests

Make sure PostgreSQL is running locally, then:

```bash
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/inventory
pytest
```

Tests skip automatically if PostgreSQL is unavailable.
