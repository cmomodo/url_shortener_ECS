# Endpoint Routing

```mermaid
flowchart LR
    Client -->|HTTPS| ALB

    ALB -->|"default (all other paths)"| API
    ALB -->|"/summary*, /top*, /recent*, /url/*"| Dashboard

    subgraph API ["API :8080"]
        A1["GET /ui"]
        A2["GET /healthz"]
        A3["POST /shorten"]
        A4["GET /stats/{short_id}"]
        A5["GET /{short_id} → redirect"]
    end

    subgraph Dashboard ["Dashboard :8081"]
        D1["GET /healthz"]
        D2["GET /summary"]
        D3["GET /top"]
        D4["GET /recent"]
        D5["GET /url/{short_code}"]
    end

    A3 --> RDS
    A4 --> RDS
    A5 --> Redis
    A5 -->|cache miss| RDS
    A5 -->|click event| SQS

    SQS --> Worker
    Worker --> RDS

    Dashboard --> RDS
```

## Request flows

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant ALB
    participant API as API :8080
    participant Redis
    participant RDS
    participant SQS
    participant Worker
    participant Dashboard as Dashboard :8081

    rect rgb(240, 248, 255)
        Note over Client, RDS: Shorten
        Client->>ALB: POST /shorten
        ALB->>API: default rule
        API->>RDS: store short mapping
        API-->>Client: short URL payload
    end

    rect rgb(255, 248, 240)
        Note over Client, SQS: Redirect and click event
        Client->>ALB: GET /{short_id}
        ALB->>API: default rule
        API->>Redis: lookup target URL
        alt cache hit
            Redis-->>API: URL
        else cache miss
            API->>RDS: load mapping
            API->>Redis: warm cache
        end
        API-->>Client: 302 Location
        API->>SQS: click event
    end

    rect rgb(245, 255, 245)
        Note over SQS, RDS: Async processing
        SQS->>Worker: deliver message
        Worker->>RDS: persist click / aggregates
    end

    rect rgb(248, 240, 255)
        Note over Client, RDS: Dashboard (ALB path rules)
        Client->>ALB: GET /summary, /top, /recent, /url/...
        ALB->>Dashboard: priority rule
        Dashboard->>RDS: read stats
        Dashboard-->>Client: JSON
    end
```

## ALB Listener Rules

| Priority | Path Pattern | Target |
|----------|-------------|--------|
| 10 | `/summary*`, `/top*`, `/recent*`, `/url/*` | Dashboard :8081 |
| default | `*` | API :8080 |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/ui` | Frontend UI |
| GET | `/healthz` | Health check |
| POST | `/shorten` | Create short URL |
| GET | `/stats/{short_id}` | Click count for a short URL |
| GET | `/{short_id}` | Redirect to original URL, publishes click event to SQS |

## Dashboard Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Health check |
| GET | `/summary` | Total URLs, total clicks, clicks today |
| GET | `/top` | Top 10 URLs by clicks |
| GET | `/recent` | Last 50 click events |
| GET | `/url/{short_code}` | Per-URL stats with 24h hourly breakdown |
