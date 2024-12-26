from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto


class combinacao_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)

    def atualiza_combinacao(obj: CombinacaoDto) -> bool:
        sql = "INSERT INTO COMBINACAO (id_tipo_jogo, nr_qtde_dezena, dezenas)  VALUES({0},{1},'{2}')"
        command = sql.format(obj.id_tipo_jogo, obj.nr_qtde_dezena, obj.dezenas)
        exec = conector.write_data(command)
        return exec

    def insere_lote_csv(arquivo: str, tabela: str) -> bool:
        exec = conector.write_to_csv(arquivo, tabela)
        return exec
        