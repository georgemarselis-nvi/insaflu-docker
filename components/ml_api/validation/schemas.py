from pydantic import BaseModel, Field
from typing import List, Optional


class TelevirValidationThresholdRequest(BaseModel):
    classifiers: List[str] = Field(..., description="List of classifiers to use for prediction")
    taxa: List[str] = Field(..., description="List of taxa to consider for prediction")
    taxon_hits: List[int] = Field(..., description="List of taxon hits corresponding to the taxa")
    kurtosis: float = Field(..., description="Kurtosis value of the distribution")
    skewness: float = Field(..., description="Skewness value of the distribution")
    mean: float = Field(..., description="Mean value of the distribution")
    median: float = Field(..., description="Median value of the distribution")
    std_dev: float = Field(..., description="Standard deviation of the distribution")

    def to_array(self):
        """
        Convert request data into a flat feature array for model prediction.
        Expects the model to handle variable-length taxon_hits via fixed-width truncation/padding.
        """
        features = []
        features.append(self.kurtosis)
        features.append(self.skewness)
        features.append(self.mean)
        features.append(self.median)
        features.append(self.std_dev)
        features.extend(self.taxon_hits)
        return features


class ThresholdValidationResult(BaseModel):
    predicted_threshold: float = Field(..., description="Predicted TELEVIR mapping threshold")
    confidence_score: float = Field(..., description="Confidence score of the prediction")
    model_version: Optional[str] = Field(None, description="Version of the model used")
    model_stage: Optional[str] = Field(None, description="MLflow stage of the model used")


class TelevirClusteringThresholdRequest(BaseModel):
    classifiers: List[str] = Field(..., description="List of classifiers to use for prediction")
    taxa: List[str] = Field(..., description="List of taxa to consider for prediction")
    taxon_hits: List[int] = Field(..., description="List of taxon hits corresponding to the taxa")
    taxonomic_diversity: float = Field(..., description="Taxonomic diversity of the sample")
    n_leaves: float = Field(..., description="Number of leaves in the cluster")
    proportion_shared_hits: float = Field(..., description="Proportion of hits shared with other clusters")
    proportion_unique_hits: float = Field(..., description="Proportion of hits unique to the cluster")

    def to_array(self):
        """
        Convert request data into a flat feature array for model prediction.
        Expects the model to handle variable-length taxon_hits via fixed-width truncation/padding.
        """
        features = []
        features.append(self.taxonomic_diversity)
        features.append(self.n_leaves)
        features.append(self.proportion_shared_hits)
        features.append(self.proportion_unique_hits)
        features.extend(self.taxon_hits)
        return features


class ClusteringThresholdResult(BaseModel):
    is_cluster: bool = Field(..., description="Indicates whether the cluster is valid or not")
    confidence_score: float = Field(..., description="Confidence score of the prediction")
    model_version: Optional[str] = Field(None, description="Version of the model used")
    model_stage: Optional[str] = Field(None, description="MLflow stage of the model used")