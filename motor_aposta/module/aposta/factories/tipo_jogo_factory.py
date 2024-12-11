from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO


class TipoJogoFactory():
    def ConverterDto(obj) -> dict:
        return TipoJogoDTO(id_tipo_jogo=obj[0][0],
                              nm_tipo_jogo=obj[0][1],
                              qt_dezena_resultado=obj[0][2],
                              qt_dezena_minima_aposta=obj[0][3],
                              qt_dezena_maxima_aposta=obj[0][4],
                              nm_route=obj[0][5], 
                              nr_concurso_max=obj[0][6])