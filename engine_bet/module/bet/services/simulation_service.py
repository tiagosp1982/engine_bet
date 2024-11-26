from itertools import combinations
from engine_bet.module.bet.dtos.simulacao_dto import SimulacaoDto
from engine_bet.module.bet.factories.simulacao_factory import SimulacaoFactory
from engine_bet.module.bet.repositories.simulation_repository import simulation_repository
from engine_bet.module.bet.repositories.type_bet_repository import type_bet_repository


def __init__(cls):
        pass

async def add_simulation(id_tipo_jogo: int, id_usuario: int, jogo: str) -> dict:
    tipo_jogo = type_bet_repository.read_type_bet(id_tipo_jogo)
    simulacao = simulation_repository.read_last_simulation(id_tipo_jogo=id_tipo_jogo,
                                                        id_usuario=id_usuario,
                                                        nr_concurso_aposta=tipo_jogo.nr_concurso_max)

    id_simulacao = (simulacao.id_simulacao if simulacao else 0)
    total = 0
    response = []
    combinacoes = list(combinations(list(jogo.split(',')), tipo_jogo.qt_dezena_resultado))
    for combinacao in combinacoes:
        id_simulacao += 1
        total += 1
        simulacao = insert(id_simulacao=id_simulacao,
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

def insert(id_simulacao: int,
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
    response = simulation_repository.save_simulation(obj)
    if (response):
        itens = SimulacaoFactory.item(obj, numeros_simulados)
        simulation_repository.save_item_simulation(itens)
         