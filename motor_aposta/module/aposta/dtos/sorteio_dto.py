from pydantic import BaseModel


class SorteioDTO:
    def __init__(self, id_tipo_jogo=None, nr_concurso=None, nr_sorteado=None) -> None:
        self.id_tipo_jogo = id_tipo_jogo
        self.nr_concurso = nr_concurso
        self.nr_sorteado = nr_sorteado
        self.lista_sorteio_dto = []
    
    def add(self,obj):
      assert isinstance(obj, SorteioDTO)
      self.lista_sorteio_dto.append(obj)

class SorteioAgrupadoDTO(BaseModel):
    nr_concurso: int
    nr_dezenas: str
    
    