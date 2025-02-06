from motor_aposta.module.aposta.dtos.concurso_dto import ConcursoDTO
from motor_aposta.module.aposta.repositories.concurso_repository import concurso_repository


async def lista_concurso(id_tipo_jogo: int) -> list[ConcursoDTO]:
    concursos = concurso_repository.busca_concurso(id_tipo_jogo)
    return [ConcursoDTO(**concurso) for concurso in concursos]