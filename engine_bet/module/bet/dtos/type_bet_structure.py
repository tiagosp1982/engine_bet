from pydantic import BaseModel


class TypeBetStructureDTO(BaseModel):
    id_tipo_jogo: int

    nr_estrutura_jogo: int