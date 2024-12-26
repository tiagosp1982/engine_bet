from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto
from motor_aposta.module.aposta.factories.combinacao_factory import CombinacaoFactory
from motor_aposta.module.aposta.repositories.combinacao_repository import combinacao_repository


def insere_combinacao(id_tipo_jogo: int, nr_qtde_dezena: int, combinacao: dict) -> bool:
    
    obj = CombinacaoDto(id_tipo_jogo=id_tipo_jogo,
                       nr_qtde_dezena=nr_qtde_dezena,
                       dezenas=str(combinacao).replace("(","").replace(")","")
                       )
    combinacao_repository.atualiza_combinacao(obj)