from pydantic import BaseModel


class ProbabilityDTO(BaseModel):
    number: int

    probability: float

