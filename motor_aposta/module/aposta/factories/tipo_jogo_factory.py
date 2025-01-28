from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO


class TipoJogoFactory():
    def ConverterParaDto(obj) -> TipoJogoDTO:
        return TipoJogoDTO(id_tipo_jogo=obj[0][0],
                            nm_tipo_jogo=obj[0][1],
                            qt_dezena_resultado=obj[0][2],
                            qt_dezena_minima_aposta=obj[0][3],
                            qt_dezena_maxima_aposta=obj[0][4],
                            nm_route=obj[0][5], 
                            nr_concurso_max=obj[0][6])

    def ConverterParaLista(data) -> dict:
        lista = []
        for d in data:
            obj = TipoJogoDTO(id_tipo_jogo=d[0],
                                nm_tipo_jogo=d[1],
                                qt_dezena_resultado=d[2],
                                qt_dezena_minima_aposta=d[3],
                                qt_dezena_maxima_aposta=d[4],
                                nm_route=d[5]
                            )
            lista.append(obj)

        return lista