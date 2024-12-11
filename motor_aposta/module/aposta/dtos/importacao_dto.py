from pydantic import BaseModel


class ImportacaoDTO(BaseModel):
    nm_tipo_jogo: str
    nr_concurso: int
    bl_importado: bool