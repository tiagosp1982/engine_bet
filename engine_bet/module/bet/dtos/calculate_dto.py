from typing import Optional
from pydantic import BaseModel


class CalculateDTO(BaseModel):
    NrDezena: Optional[int] = None

    QtAusenciaRecente: Optional[int] = None

    QtAusenciaTotal: Optional[int] = None

    QtRepeticaoRecente: Optional[int] = None

    QtRepeticaoTotal: Optional[int] = None

    VlProbabilidade: Optional[float] = None
