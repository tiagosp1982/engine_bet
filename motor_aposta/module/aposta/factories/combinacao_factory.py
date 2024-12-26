from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto


class CombinacaoFactory():
    def item(obj: CombinacaoDto, combinacao: dict) -> dict:
        lista = []
        for n in combinacao:
            item = [obj.id_combinacao, obj.id_tipo_jogo, obj.nr_qtde_dezena, n]
            lista.append(item)
        
        return lista