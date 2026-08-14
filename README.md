# HydraFuel

MVP para relógios Garmin Connect IQ focado em registro rápido de líquidos,
estimativa individualizada de suor, eletrólitos e acompanhamento de cafeína.

> Este projeto é uma ferramenta educacional para adultos saudáveis. Não faz
> diagnóstico e não substitui avaliação médica ou de nutrição esportiva.

## Arquitetura

- **Device App (`watch-app`)**: UI interativa e armazenamento local.
- **Glance**: resumo rápido de água e cafeína.
- **Background Service**: snapshot periódico de métricas disponíveis e evento
  de atividade concluída. Não é execução contínua.
- **Data Field futuro**: camada indicada para alertas dentro de uma atividade.

O Device App com Glance é a base mais adequada para produtos atuais. O serviço
de background pertence ao app; eventos temporais têm intervalo mínimo de cinco
minutos e execução controlada pelo sistema.

Documentação Garmin:

- [Tipos de aplicativo](https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/)
- [Glances](https://developer.garmin.com/connect-iq/core-topics/glances/)
- [Background](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html)
- [Métricas do usuário](https://developer.garmin.com/connect-iq/core-topics/quantifying-the-user/)

## Funcionalidades implementadas

- Registro de água, eletrólitos, cafés, chás, suco e refrigerante zero.
- Monster Zero `473 ml / 142 mg` e Red Bull `250 ml / 80 mg`.
- Cada lançamento do dia registra bebida, hidratação creditada, cafeína e
  origem; na virada, o histórico compacto preserva os totais e a meta do dia.
- Reinício diário dos totais, arquivando até 366 dias e preservando doses de
  cafeína das últimas 48 h.
- Relatórios de 7 dias, 4 semanas e 1 ano, com média, baixa, alta, metas
  atingidas e gráfico por período.
- Registro pelo celular usando as configurações do HydraFuel no Garmin
  Connect ou no Connect IQ Store.
- Estimativa de cafeína ainda não eliminada com meia-vida configurada no código.
- Leitura segura do peso em `UserProfile`, com fallback explícito.
- Leitura oportunista de calorias, stress e Body Battery, quando suportados.
- Glance com totais do dia.
- Serviço temporal e callback de atividade concluída.
- Motor isolado para suor, sódio, potássio e cafeína.

Controles: deslize ou use `UP/DOWN` para alternar entre painel, resumo diário e
relatório. No painel, toque ou use `START` para abrir as bebidas. No relatório,
`START/SELECT` alterna entre `7D`, `4S` e `1A`.

### Registrar uma bebida pelo celular

Abra as configurações do HydraFuel no Garmin Connect ou no Connect IQ Store:

1. Escolha **Bebida para adicionar pelo celular**.
2. Escolha de uma a três porções.
3. Alterne **Adicionar agora** e salve. Para o lançamento seguinte, alterne o
   botão novamente e salve.

Cada valor sincronizado do botão é consumido uma vez nas execuções normais. Se
o relógio estiver desconectado, o lançamento entra quando as configurações forem
sincronizadas e o HydraFuel ou o serviço de background executar. Aguarde a
sincronização antes de alternar novamente: App Settings é um formulário de
estado, não uma fila, então várias alterações pendentes podem ser condensadas.
Uma interrupção exatamente durante a gravação também pode perder o comando; uma
garantia transacional exigiria um app companion com identificadores e ACKs.

Essa integração usa o formulário público de [App Settings do Connect
IQ](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/).
Ela não grava na tela nativa **Hidratação** do Garmin Connect mostrada no vídeo:
a API pública do Connect IQ não oferece escrita nessa métrica. Um relatório
completo no celular exigiria um app companion iOS/Android separado e a
[comunicação com apps móveis](https://developer.garmin.com/connect-iq/core-topics/communicating-with-mobile-apps/).

## Modelo fisiológico

### Meta inicial de líquidos

O onboarding usa provisoriamente:

```text
meta_estimada_ml = clamp(35 × peso_kg, 1800, 5000)
```

Isso é uma heurística editável, não uma necessidade clínica validada. A tela
deve chamá-la de “meta estimada de líquidos registrados”. Água total também
inclui alimentos e outras bebidas.

### Taxa de suor calibrada

```text
perda_suor_L = peso_pre_kg - peso_pos_kg + liquido_durante_L - urina_L
taxa_suor_L_h = perda_suor_L / duracao_h
```

Pesagem: atleta seco, pouca roupa, mesma balança e bexiga esvaziada. Repetir em
esporte, intensidade e ambiente semelhantes. Um resultado negativo permanece
visível porque pode representar sobreingestão ou erro de entrada.

Sem calibração, o app usa apenas um prior de baixa confiança de `0,7 L/h`,
mostrando faixa ampla de `0,4–1,0 L/h`. FC, calorias e temperatura não são
transformadas em uma falsa fórmula precisa.

Confiança de produto:

- baixa: nenhum teste;
- média: pelo menos um teste;
- alta: três ou mais testes semelhantes e variação de até 20%.

Referência: [NATA — Fluid Replacement for the Physically Active](https://pmc.ncbi.nlm.nih.gov/articles/PMC5634236/).

### Eletrólitos

```text
sodio_perdido_mg = suor_L × sodio_suor_mg_L
potassio_perdido_mg = suor_L × potassio_suor_mg_L
```

- Prior de concentração no suor: sódio `920 mg/L`; potássio `156 mg/L`.
- Ambos têm grande variação individual e devem ser calibráveis.
- Sugestão inicial da bebida para exercício prolongado/quente: `500–700 mg` de
  sódio por litro.
- A concentração da bebida não é igual à concentração estimada no suor.
- Não sugerir comprimidos de potássio ou afirmar “deficiência”.
- Sódio não impede hiponatremia se o usuário beber líquido em excesso.

Regra conservadora: abaixo de 60 minutos em clima ameno, água e alimentação
habitual geralmente bastam. Em duração maior, calor, sessões repetidas ou suor
alto/salgado, mostrar a opção de bebida com eletrólitos — nunca uma obrigação.

### Cafeína

```text
dose_mg_kg = dose_mg / peso_kg
remanescente_mg(t) = soma(dose_i × 0,5^(horas_i / meia_vida_h))
```

A estimativa de remanescente não é concentração sanguínea nem previsão exata
de efeito/sono. Default: meia-vida de `5 h`; a variação adulta pode ser ampla.

Indicador de performance e indicador de segurança são separados:

- `<1 mg/kg`: efeito incerto;
- `1–2 mg/kg`: benefício possível;
- `2–3 mg/kg`: benefício provável em alguns usuários;
- `3–6 mg/kg`: evidência mais consistente, com maior risco de efeitos adversos;
- `>=6 mg/kg`: não sugerir automaticamente;
- `>=9 mg/kg`: alerta forte.

Guardrails conservadores para adultos saudáveis:

```text
alerta_dose_unica = min(200 mg, 3 mg/kg)
alerta_diario = min(400 mg, 5,7 mg/kg)
```

Esses valores são limites de alerta, não metas nem garantia de segurança.
Referências: [ISSN — Caffeine and Exercise Performance](https://link.springer.com/article/10.1186/s12970-020-00383-4) e
[EFSA — Caffeine](https://www.efsa.europa.eu/en/topics/topic/caffeine).

## Dados Garmin e limites

- `UserProfile.weight` é fornecido em gramas e pode ser nulo.
- `ActivityMonitor` oferece métricas do dia, não hidratação direta.
- `SensorHistory.getBodyBatteryHistory()` exige aparelho compatível.
- Body Battery, stress, FC e calorias não diagnosticam desidratação. Eles só
  podem modular horário e linguagem dos lembretes.
- A API pública não entrega uma perda universal de suor pronta. O produto deve
  aprender com pesagens pré/pós-atividade.
- Temperatura medida no pulso não equivale à temperatura ambiente.

## Segurança obrigatória para evolução do produto

Desabilitar recomendações automáticas e pedir orientação profissional para
menores de 18 anos, gestação/lactação, doença renal, cardíaca ou hepática,
hipertensão não controlada, diuréticos/medicações que alterem sódio e histórico
de hiponatremia ou doença pelo calor.

Confusão, convulsão, colapso, falta de ar, edema, cefaleia intensa ou vômitos
repetidos durante/depois de exercício não devem gerar “beba mais água”; devem
gerar orientação de interromper ingestão forçada e procurar atendimento.

## Estrutura

```text
HydraFuel/
├── manifest.xml
├── monkey.jungle
├── resources/
├── resources-venu445mm/
├── resources-por/
└── source/
    ├── HydraFuelApp.mc
    ├── AppConfig.mc
    ├── HydrationStore.mc
    ├── HydrationCalculator.mc
    ├── WellnessReader.mc
    ├── DashboardView.mc
    ├── HydrationGlanceView.mc
    └── HydrationServiceDelegate.mc
```

## Compilar

O projeto está validado com o Connect IQ SDK 9.2.0. No VS Code, abra um arquivo
`.mc`, pressione `Ctrl+F5` e escolha um destes alvos:

```text
Forerunner 165
Forerunner 165 Music
Venu 4 41mm
Venu 4 45mm
```

Para testar no relógio físico, use `Monkey C: Build for Device` e gere um
`.prg` separado para o modelo exato. Para a loja, use
`Monkey C: Export Project` e envie o arquivo `.iq`.

### Testar lembretes no relógio

Depois de instalar uma nova versão, abra o HydraFuel uma vez. Isso registra ou
migra o serviço periódico para 15 minutos. O item **Testar Notificação** valida
apenas a permissão e a exibição; os lembretes automáticos também dependem da
janela de 08:00–22:30, do déficit e dos cooldowns.

O item **Diagnóstico** mostra:

- `N`, `R` e `API`: notificações, lembretes e suporte do relógio;
- `BG | 15m`: serviço registrado e intervalo solicitado;
- `Run`: última execução e por que o motor enviou ou aguardou;
- `Notif`: última notificação aceita pela API;
- `Today`, `Level` e `Quiet`: limite diário, severidade e pausa após água.

Política atual: checagem leve a cada 15 minutos, snapshot de sensores a cada
hora, pausa de 45 minutos apenas para registros de pelo menos 200 ml, faixas de
déficit em 200/450/800 ml e no máximo dez lembretes por dia. A execução real
continua sujeita ao agendamento do sistema do relógio.

As frases possuem um cursor persistente separado por nível. O app percorre
todas as mensagens daquela faixa antes de reutilizar uma e continua a rotação
mesmo depois de fechar o app ou virar o dia. A mensagem variável é enviada
também no corpo da notificação, porque alguns modelos ocultam o subtítulo na
prévia e no histórico.

### Pop!_OS 24.04

O simulador do SDK 9.2.0 ainda depende dos nomes WebKitGTK 4.0 e de libsoup2,
enquanto o sistema fornece WebKitGTK 4.1 com libsoup3. Nesta máquina foi
instalado um launcher de compatibilidade dentro do próprio SDK. O executável
Garmin original está preservado como `bin/simulator.garmin-original`; uma
atualização do SDK pode exigir reaplicar essa compatibilidade.

## Próximos incrementos

1. Onboarding e edição da meta de líquidos.
2. Volumes e cafeína editáveis por embalagem/variante.
3. Formulário de pesagem pré/pós e histórico de calibrações por esporte/clima.
4. Cartão de eletrólitos com intervalo e confiança explícitos.
5. Horário de sono e alertas por dose + horário.
6. Data Field complementar para atividade em andamento.
7. Companion iOS/Android opcional para relatório completo no celular.
