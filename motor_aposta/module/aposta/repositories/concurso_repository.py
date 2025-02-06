from atexit import register
from motor_aposta.infrastructure.database.conector import conector
from motor_aposta.module.aposta.dtos.concurso_dto import ConcursoDTO
from motor_aposta.module.aposta.dtos.sorteio_dto import SorteioDTO


class concurso_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)
    
    def atualiza_concurso(obj: ConcursoDTO) -> bool:
        if obj.dt_proximo_concurso == "":
            instruction = """INSERT INTO CONCURSO (id_tipo_jogo, nr_concurso, dt_concurso, vl_acumulado, nr_proximo_concurso, nr_ganhador)
                            VALUES({0},{1},'{2}',{3},{4},{5})"""
            command = instruction.format(obj.id_tipo_jogo, obj.nr_concurso, obj.dt_concurso, obj.vl_acumulado, obj.nr_proximo_concurso, obj.nr_ganhador)
        else:
            instruction = """INSERT INTO CONCURSO (id_tipo_jogo, nr_concurso, dt_concurso, vl_acumulado, nr_proximo_concurso, dt_proximo_concurso, nr_ganhador)
                            VALUES({0},{1},'{2}',{3},{4},'{5}',{6})"""
            command = instruction.format(obj.id_tipo_jogo, obj.nr_concurso, obj.dt_concurso, obj.vl_acumulado, obj.nr_proximo_concurso, None if obj.dt_proximo_concurso == "" else obj.dt_proximo_concurso, obj.nr_ganhador)
        print(f'Concurso {command}')
        exec = conector.write_data(command)
        return exec
    
    def atualiza_sorteio(obj: SorteioDTO) -> bool:
        command = "INSERT INTO public.sorteio(id_tipo_jogo, nr_concurso, nr_sorteado) VALUES (%s, %s, %s)"
        print(f'Sorteio {command}')
        exec = conector.write_data_many(command, obj)
        return exec
    
    def atualiza_ciclo(id_tipo_jogo) -> bool:
        instruction = """CALL public.gera_ciclo({0})"""
        command = instruction.format(id_tipo_jogo)
        exec = conector.write_data(command)
        return exec

    def busca_concurso(_id_tipo_jogo: int) -> dict:
        data = conector.read_data_new(f"""select id_tipo_jogo
                                          	   , nr_concurso
                                          	   , dt_concurso
                                          	   , vl_acumulado
                                          	   , nr_proximo_concurso
                                          	   , dt_proximo_concurso
                                          	   , nr_ganhador 
                                            from concurso c 
                                           where id_tipo_jogo = {_id_tipo_jogo}
                                           order by nr_concurso """
                                )
        return data