from atexit import register
from engine_bet.infrastructure.database.conector import conector
from engine_bet.module.bet.dtos.contest_dto import ContestDto
from engine_bet.module.bet.dtos.raffle_dto import RaffleDto


class contest_repository:
    def __init__(cls, **kwargs):
        super().__init__(**kwargs)
        register(cls)
    
    def write_data_contest(obj: ContestDto) -> bool:
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
    
    def write_data_raffle(obj: RaffleDto) -> bool:
        command = "INSERT INTO public.sorteio(id_tipo_jogo, nr_concurso, nr_sorteado) VALUES (%s, %s, %s)"
        print(f'Sorteio {command}')
        exec = conector.write_data_many(command, obj)
        return exec
    
    def update_cicle_data(id_tipo_jogo) -> bool:
        instruction = """CALL public.gera_ciclo({0})"""
        command = instruction.format(id_tipo_jogo)
        exec = conector.write_data(command)
        return exec