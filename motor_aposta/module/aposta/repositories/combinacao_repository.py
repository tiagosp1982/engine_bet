from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto, CombinacaoFormatadaDto
from motor_aposta.module.aposta.dtos.combinacao_sorteio_dto import CombinacaoSorteioDto


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

    def busca_combinacao(_id_tipo_jogo: int, _nr_qtde_dezena: int) -> dict:
        data = conector.read_data(f"""select id_combinacao
                                           , nr_dezenas
                                        from combinacao c 
                                       where id_tipo_jogo = {_id_tipo_jogo}
                                         and nr_qtde_dezena = {_nr_qtde_dezena} 
                                         and flg_improvavel = 'S'""")
        if (data == None):
            return None

        return [CombinacaoFormatadaDto(id_combinacao=res[0],
                                       nr_dezenas=res[1]) for res in data]

    def atualizacao_combinacao_sorteio(obj: CombinacaoSorteioDto) -> bool:
        sql = """INSERT INTO public.combinacao_sorteio(id_tipo_jogo, nr_qtde_dezena, id_combinacao, nr_concurso) 
                                                VALUES({0}, {1}, {2}, {3}) 
                                          ON CONFLICT (id_tipo_jogo, nr_qtde_dezena, id_combinacao, nr_concurso) 
                                          DO NOTHING;"""
        command = sql.format(obj.id_tipo_jogo, obj.nr_qtde_dezena, obj.id_combinacao, obj.nr_concurso)
        exec = conector.write_data(command)
        return exec

    def atualiza_jogo_improvavel(id_tipo_jogo: int, nr_qtde_dezena: int, id_combinacao: int) -> bool:
        sql = """UPDATE public.combinacao
                    SET flg_improvavel='S'::bpchar
                  WHERE id_tipo_jogo={0}
                    AND nr_qtde_dezena={1}
                    AND id_combinacao={2}"""
        command = sql.format(id_tipo_jogo, nr_qtde_dezena, id_combinacao)
        exec = conector.write_data(command)
        return exec
