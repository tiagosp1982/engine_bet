from motor_aposta.module.aposta.dtos.combinacao_dto import CombinacaoDto, CombinacaoFormatadaDto


class CombinacaoFactory():
    def item(obj: CombinacaoDto, combinacao: dict) -> dict:
        lista = []
        for n in combinacao:
            item = [obj.id_combinacao, obj.id_tipo_jogo, obj.nr_qtde_dezena, n]
            lista.append(item)
        
        return lista
    
    def ConverteListaParaInt(obj: dict) -> dict:
        lista = []
        for o in obj:
            item = []
            n = []
            dezenas = o.nr_dezenas.split(', ')
            for d in dezenas:
                n.append(int(d))

            item = [o.id_combinacao, n]
            lista.append(item)

        return lista
            
        