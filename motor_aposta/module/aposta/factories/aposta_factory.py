from motor_aposta.module.aposta.dtos.aposta_dto import ApostaDto
from motor_aposta.module.aposta.dtos.aposta_item_dto import ApostaItemDto


class ApostaFactory():
    def item(obj: ApostaDto, aposta: dict) -> ApostaItemDto:
        list = []
        for n in aposta:
            item = [obj.id_aposta, obj.id_usuario, obj.id_tipo_jogo, obj.nr_concurso, int(n)]
            list.append(item)
        
        return list
