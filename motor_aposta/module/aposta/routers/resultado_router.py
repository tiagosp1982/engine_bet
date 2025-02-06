from fastapi import APIRouter
from motor_aposta.module.aposta.services.resultado_service import confere_resultado_consolidado, confere_resultado_detalhado, lista_sorteios_por_concurso


router = APIRouter(prefix="/resultado")


@router.get("/detalhado")
async def resultado_detalhado(tipo_jogo: int, lista_bet: str):
    response = await confere_resultado_detalhado(tipo_jogo, lista_bet)
    return response

@router.get("/consolidado")
async def resultado_consolidado(id_tipo_jogo: int, lista_bet: str):
    response = await confere_resultado_consolidado(id_tipo_jogo, lista_bet)
    return response

@router.get("/lista/{id_tipo_jogo}/{nr_concurso_inicial}/{nr_concurso_final}")
async def lista_sorteio_por_concurso(id_tipo_jogo: int, nr_concurso_inicial: int, nr_concurso_final: int):
    response = await lista_sorteios_por_concurso(id_tipo_jogo, nr_concurso_inicial, nr_concurso_final)
    return response