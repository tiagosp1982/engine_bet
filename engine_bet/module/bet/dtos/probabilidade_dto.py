from pydantic import BaseModel


class ProbabilidadeDTO(BaseModel):
    numero: int

    probabilidade: float

