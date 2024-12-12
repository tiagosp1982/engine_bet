from pydantic import BaseModel


class TipoJogoEstruturaDTO(BaseModel):
    id_tipo_jogo: int

    nr_estrutura_jogo: int