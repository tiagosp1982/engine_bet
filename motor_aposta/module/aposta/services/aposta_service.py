import datetime
from motor_aposta.module.aposta.dtos.aposta_dto import ApostaDto
from motor_aposta.module.aposta.dtos.aposta_carrinho_dto import ApostaCarrinhoDto
from motor_aposta.module.aposta.factories.aposta_factory import ApostaFactory
from motor_aposta.module.aposta.repositories.aposta_repository import aposta_repository
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
from motor_aposta.module.aposta.factories.sorteio_factory import SorteioFactory


def __init__(cls):
    pass

async def cria_aposta(id_tipo_jogo: int, id_usuario: int, nr_jogo: str) -> dict:
    gera_aposta(id_tipo_jogo=id_tipo_jogo, id_usuario=id_usuario, nr_jogo=nr_jogo)

async def lista_aposta_carrinho(id_tipo_jogo: int, id_usuario: int, nr_concurso: int) -> dict:
    return lista_carrinho(id_tipo_jogo=id_tipo_jogo,
                        id_usuario=id_usuario,
                        nr_concurso=nr_concurso)  

def gera_aposta(id_tipo_jogo: int, id_usuario: int, nr_jogo: str) -> dict:
    tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
    aposta_dto = aposta_repository.busca_ultima_aposta(id_tipo_jogo=id_tipo_jogo,
                                                        id_usuario=id_usuario,
                                                        nr_concurso_aposta=tipo_jogo.nr_concurso_max)

    id_aposta = (aposta_dto.id_aposta + 1 if aposta_dto else 1)
    insere_aposta(id_aposta=id_aposta,
                    id_usuario=id_usuario,
                    id_tipo_jogo=id_tipo_jogo,
                    nr_concurso=tipo_jogo.nr_concurso_max,
                    numeros_aposta=list(nr_jogo.split(','))
                )
    
    return {'Loteria:': tipo_jogo.nm_tipo_jogo,
            "Concurso:": tipo_jogo.nr_concurso_max,
            "Aposta:": True
            }


def insere_aposta(id_aposta: int,
                    id_tipo_jogo: int,
                    id_usuario: int,
                    nr_concurso: int,
                    numeros_aposta: dict,
                    ) -> bool:

    obj = ApostaDto(id_aposta=id_aposta,
                       id_tipo_jogo=id_tipo_jogo,
                       id_usuario=id_usuario,
                       nr_concurso=nr_concurso,
                       dt_aposta=datetime.date.today())

    # cabeçalho da aposta
    response = aposta_repository.atualiza_aposta(obj)
    if (response):
        # itens da aposta
        itens = ApostaFactory.item(obj, numeros_aposta)
        aposta_repository.atualiza_aposta_item(itens)

def lista_carrinho(id_tipo_jogo: int, id_usuario: int, nr_concurso: int) -> list[ApostaCarrinhoDto]:
    lista_aposta = []
    apostas:ApostaCarrinhoDto = aposta_repository.busca_aposta_carrinho(id_tipo_jogo, id_usuario, nr_concurso)
    sorteados = sorteio_repository.busca_resultado_por_concurso(id_tipo_jogo,nr_concurso - 1)
    for aposta in apostas:
        a = list(map(int, aposta.jogo.split(',')))
        repetidos = [s.nr_sorteado for s in sorteados if s.nr_sorteado in a]
        aposta.repetidos = ",".join(map(str, repetidos))
        lista_aposta.append(aposta)
    return lista_aposta
