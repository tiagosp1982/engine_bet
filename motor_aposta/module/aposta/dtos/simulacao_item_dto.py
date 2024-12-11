from pydantic import BaseModel


class SimulacaoItemDto(BaseModel):
    nr_concurso: int

    nr_simulado: int
    