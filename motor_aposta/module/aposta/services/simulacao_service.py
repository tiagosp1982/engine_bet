from itertools import combinations
from motor_aposta.module.aposta.dtos.simulacao_dto import SimulacaoDto
from motor_aposta.module.aposta.factories.simulacao_factory import SimulacaoFactory
from motor_aposta.module.aposta.repositories.simulacao_repository import simulacao_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository


def __init__(cls):
        pass

async def cria_simulacao(id_tipo_jogo: int, id_usuario: int, jogo: str) -> dict:
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
    simulacao = simulacao_repository.busca_ultima_simulacao(id_tipo_jogo=id_tipo_jogo,
                                                        id_usuario=id_usuario,
                                                        nr_concurso_aposta=tipo_jogo.nr_concurso_max)

    id_simulacao = (simulacao.id_simulacao if simulacao else 0)
    total = 0
    response = []
    combinacoes = list(combinations(list(jogo.split(',')), tipo_jogo.qt_dezena_resultado))
    for combinacao in combinacoes:
        id_simulacao += 1
        total += 1
        simulacao = insere(id_simulacao=id_simulacao,
                            id_usuario=id_usuario,
                            id_tipo_jogo=id_tipo_jogo,
                            nr_concurso=tipo_jogo.nr_concurso_max,
                            numeros_simulados=combinacao,
                            tp_geracao='M'
                        )
    
    response.append({'Loteria:': tipo_jogo.nm_tipo_jogo,
                        "Concurso:": tipo_jogo.nr_concurso_max,
                        "Jogo(s) Gerado(s):": total
                        }
                    )
    return response

def insere(id_simulacao: int,
                    id_tipo_jogo: int,
                    id_usuario: int,
                    nr_concurso: int,
                    numeros_simulados: dict,
                    tp_geracao: str = 'A',) -> bool:

    obj = SimulacaoDto(id_simulacao=id_simulacao,
                       id_tipo_jogo=id_tipo_jogo,
                       id_usuario=id_usuario,
                       nr_concurso=nr_concurso,
                       tp_geracao=tp_geracao)
    response = simulacao_repository.atualiza_simulacao(obj)
    if (response):
        itens = SimulacaoFactory.item(obj, numeros_simulados)
        simulacao_repository.atualiza_simulacao_item(itens)
         