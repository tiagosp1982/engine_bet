from typing import Optional
from pydantic import BaseModel


class CalculateDTO(BaseModel):
    NrDezena: Optional[int]

    QtAusenciaRecente: Optional[int]

    QtAusenciaTotal: Optional[int]

    QtRepeticaoRecente: Optional[int]

    QtRepeticaoTotal: Optional[int]

    VlProbabilidade: Optional[float]
