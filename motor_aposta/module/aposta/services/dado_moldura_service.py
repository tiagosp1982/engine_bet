import os
from pyexpat import model
import warnings

from typing import Optional
from xml.parsers.expat import model
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
warnings.filterwarnings("ignore")

from tensorflow.keras.preprocessing.sequence import pad_sequences
from motor_aposta.module.aposta.dtos.tipo_jogo_dto import TipoJogoDTO
from motor_aposta.module.aposta.repositories.sorteio_repository import sorteio_repository
import pandas as pd
import numpy as np
import tensorflow as tf
from keras.layers import LSTM, Dense
from keras.models import Sequential
import random

from motor_aposta.module.aposta.dtos.tipo_jogo_estrutura_dto import TipoJogoEstruturaDTO
from motor_aposta.module.aposta.repositories.tipo_jogo_repository import tipo_jogo_repository

class DadoMolduraService():
    def __init__():
        pass

    def dado_moldura(id_tipo_jogo: int,
                     moldura_inicial: int = 10,
                     moldura_final: int = 11,
                     analisa_simulacao: bool = False) -> Optional[dict]:
        tipo_jogo: TipoJogoDTO
        tipo_jogo_estrutura: TipoJogoEstruturaDTO

        tipo_jogo = tipo_jogo_repository.busca_tipo_jogo(id_tipo_jogo)
        tipo_jogo_estrutura = tipo_jogo_repository.busca_tipo_jogo_estrutura(id_tipo_jogo)
        sorteio_moldura = sorteio_repository.busca_resultado_moldura(id_tipo_jogo=id_tipo_jogo,
                                                                     analisa_simulacao=analisa_simulacao,
                                                                     nr_concurso=tipo_jogo.nr_concurso_max)

        # Configurações
        CONJUNTO_BASE = [t.nr_estrutura_jogo for t in tipo_jogo_estrutura if t.flg_centro_moldura == 'M']
        TAMANHO_ENTRADA = 20
        SORTEIO_MIN = moldura_inicial
        SORTEIO_MAX = moldura_final
        EPOCHS = 25

        # 1. Carregar e preparar os dados
        df = pd.DataFrame(sorteio_moldura)
        df['ds_dezenas'] = df['ds_dezenas'].apply(lambda x: list(map(int, x.split(','))))

        def dezenas_para_binario(dezenas, conjunto):
            return [1 if numero in dezenas else 0 for numero in conjunto]

        dados_binarios = np.array([dezenas_para_binario(linha, CONJUNTO_BASE) for linha in df['ds_dezenas']])

        X, y = [], []
        for i in range(len(dados_binarios) - TAMANHO_ENTRADA):
            seq = dados_binarios[i:i+random.randint(10, TAMANHO_ENTRADA)]  # sequência variável
            seq_padded = pad_sequences([seq], maxlen=TAMANHO_ENTRADA, dtype='float32')
            X.append(seq_padded[0])
            y.append(dados_binarios[i+len(seq)])  # próximo sorteio
        X, y = np.array(X), np.array(y)

        # Ajustar formato para LSTM (batch, time_steps, features)
        X = X.reshape(X.shape[0], TAMANHO_ENTRADA, X.shape[2])

        # 2. Criar e treinar o modelo
        model = Sequential()
        model.add(LSTM(64, input_shape=(X.shape[1], X.shape[2]), activation='relu'))
        model.add(Dense(len(CONJUNTO_BASE), activation='sigmoid'))
        model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
        model.fit(X, y, epochs=EPOCHS, verbose=0)

        # 3. Prever próximo sorteio
        # num_entrada = random.randint(10, 20)
        # entrada = dados_binarios[-num_entrada:]  # pega últimos sorteios
        # entrada = entrada.reshape(1, entrada.shape[0], entrada.shape[1])  # (batch, time_steps, features)
        # pred = model.predict(entrada)[0]

# Preparar X e y com padding
        

        num_entrada = random.randint(10, 20)
        entrada = dados_binarios[-num_entrada:] 
        entrada_padded = pad_sequences([entrada], maxlen=TAMANHO_ENTRADA, dtype='float32')
        pred = model.predict(entrada_padded)[0]

        # 4. Ordenar dezenas pela probabilidade prevista
        dezenas_ordenadas = [x for _, x in sorted(zip(pred, CONJUNTO_BASE), reverse=True)]


        # 5. Obter todos os conjuntos sorteados anteriores
        historico_sets = [set(dez) for dez in df['ds_dezenas']]

        # 6. Gerar conjunto previsto que nunca foi sorteado
        def gerar_conjunto_valido():
            for _ in range(1000):  # tenta até 1000 vezes
                tamanho = random.randint(SORTEIO_MIN, SORTEIO_MAX)
                candidato = set(dezenas_ordenadas[:tamanho])
                if candidato not in historico_sets:
                    return sorted(candidato)
            return candidato

        resultado = gerar_conjunto_valido()
        # 7. Resultado
        if resultado:
            return list(resultado)
        return None
