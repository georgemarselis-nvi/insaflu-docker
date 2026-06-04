# INSaFLU ML API

FastAPI service serving ML models registered in MLflow for the INSaFLU platform.

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET`  | `/health`                          | Liveness check |
| `GET`  | `/models`                          | List cached models with version/stage |
| `POST` | `/reload`                          | Reload all models from MLflow registry |
| `POST` | `/reload/{model_type}`             | Reload a single model |
| `POST` | `/predict/{model_type}`            | Generic prediction (feature vector body) |
| `GET`  | `/predict_televir_threshold`       | TELEVIR mapping threshold prediction |
| `GET`  | `/predict_televir_clustering_threshold` | TELEVIR clustering threshold prediction |

## Model serving

Models are loaded from the MLflow registry into an in-memory cache at startup.
To switch to a new model version after promoting it in MLflow:

    curl -X POST http://localhost:8000/reload/televir_mapping_threshold

## Environment

- `MLFLOW_TRACKING_URI` — MLflow server URL (default: `http://mlflow:5000`)
- `MLFLOW_EXPERIMENT` — MLflow experiment name (default: `INSaFLU_ML_API`)

## Build & run

    docker compose up ml_app
