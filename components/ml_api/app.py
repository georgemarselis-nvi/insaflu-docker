from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel
from typing import Optional, List
from ml_api.validation.schemas import TelevirValidationThresholdRequest, TelevirClusteringThresholdRequest, ClusteringThresholdResult, ThresholdValidationResult
import time
from monitoring import log_prediction, get_metrics
from registry import load_and_cache, get_cached_model, invalidate_cache, cache_status
from config import registry_name, PROJECT_MODELS, get_logger

logger = get_logger(__name__)

app = FastAPI(title="INSaFLU ML API", description="API for INSaFLU machine learning models", version="1.0.0")


class PredictRequest(BaseModel):
    features: List[float]


class PredictResponse(BaseModel):
    prediction: float
    confidence_score: float
    model_version: Optional[str] = None
    model_stage: Optional[str] = None


@app.on_event("startup")
def warmup_cache():
    for mt in PROJECT_MODELS:
        try:
            load_and_cache(mt)
        except Exception as e:
            logger.warning(f"Failed to preload '{mt}': {e}")
    logger.info(f"Cache warmup complete ({cache_status()})")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/models")
def list_models():
    return {"models": cache_status()}


@app.post("/reload")
def reload_all():
    invalidate_cache()
    count = 0
    errors = []
    for mt in PROJECT_MODELS:
        try:
            load_and_cache(mt)
            count += 1
        except Exception as e:
            errors.append({"model_type": mt, "error": str(e)})
    return {"reloaded": count, "errors": errors}


@app.post("/reload/{model_type}")
def reload_one(model_type: str):
    if model_type not in PROJECT_MODELS:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown model type: '{model_type}'. Available: {PROJECT_MODELS}",
        )
    invalidate_cache(model_type)
    try:
        load_and_cache(model_type)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    return {"reloaded": model_type}


@app.post("/predict/{model_type}", response_model=PredictResponse)
def predict_generic(model_type: str, request: PredictRequest, response: Response):
    if model_type not in PROJECT_MODELS:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown model type: '{model_type}'. Available: {PROJECT_MODELS}",
        )
    start = time.time()
    try:
        model, version_info = get_cached_model(model_type)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    X = request.features
    prediction = model.predict([X])[0]
    confidence_score = 0.9
    latency_ms = (time.time() - start) * 1000
    log_prediction(
        model_version=f"{registry_name(model_type)} v{version_info.get('version', '?')}",
        prediction=float(prediction),
        latency_ms=latency_ms,
    )

    response.headers["X-Model-Version"] = str(version_info.get("version", ""))
    response.headers["X-Model-Stage"] = str(version_info.get("stage", ""))
    return PredictResponse(
        prediction=float(prediction),
        confidence_score=confidence_score,
        model_version=str(version_info.get("version")),
        model_stage=version_info.get("stage"),
    )


@app.get("/predict_televir_threshold", response_model=ThresholdValidationResult)
def predict_televir_mapping_threshold(request: TelevirValidationThresholdRequest, response: Response):
    start = time.time()
    model_type = "televir_mapping_threshold"
    try:
        model, version_info = get_cached_model(model_type)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    X = request.to_array()
    predicted_threshold = model.predict([X])[0]
    confidence_score = 0.9
    latency_ms = (time.time() - start) * 1000
    log_prediction(
        model_version=f"{registry_name(model_type)} v{version_info.get('version', '?')}",
        prediction=float(predicted_threshold),
        latency_ms=latency_ms,
    )

    response.headers["X-Model-Version"] = str(version_info.get("version", ""))
    response.headers["X-Model-Stage"] = str(version_info.get("stage", ""))
    return ThresholdValidationResult(
        predicted_threshold=float(predicted_threshold),
        confidence_score=confidence_score,
        model_version=str(version_info.get("version")),
        model_stage=version_info.get("stage"),
    )


@app.get("/predict_televir_clustering_threshold", response_model=ClusteringThresholdResult)
def predict_televir_clustering_threshold(request: TelevirClusteringThresholdRequest, response: Response):
    start = time.time()
    model_type = "televir_clustering"
    try:
        model, version_info = get_cached_model(model_type)
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    X = request.to_array()
    prediction = model.predict([X])[0]
    confidence_score = 0.85
    latency_ms = (time.time() - start) * 1000
    log_prediction(
        model_version=f"{registry_name(model_type)} v{version_info.get('version', '?')}",
        prediction=float(prediction),
        latency_ms=latency_ms,
    )

    response.headers["X-Model-Version"] = str(version_info.get("version", ""))
    response.headers["X-Model-Stage"] = str(version_info.get("stage", ""))
    return ClusteringThresholdResult(
        is_cluster=bool(prediction),
        confidence_score=confidence_score,
        model_version=str(version_info.get("version")),
        model_stage=version_info.get("stage"),
    )
