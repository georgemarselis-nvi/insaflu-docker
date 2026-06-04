import os
from pathlib import Path
import logging

PROJECT_NAME = "INSaFLU_ML_API"
RANDOM_SEED = 42
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

MLFLOW_TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
MLFLOW_EXPERIMENT = os.getenv("MLFLOW_EXPERIMENT", PROJECT_NAME)
MLRUNS_DIR = os.getenv("MLRUNS_DIR", "./mlruns")
FEATURES_DIR = os.path.join(DATA_DIR, "features")

PROJECT_MODELS = ["televir_mapping_threshold", "televir_clustering"]

def registry_name(model_type):
    return f"{PROJECT_NAME}_{model_type}"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

def get_logger(name):
    return logging.getLogger(name)


class ModelFile:
    
    project_files = {
        "televir_mapping_threshold": "composition_xgb_bundle.pkl",
        "televir_clustering": "clustering_xgb_bundle.pkl"
    }