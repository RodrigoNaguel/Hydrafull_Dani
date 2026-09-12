# HydraFuel Face

Watch face complementar do HydraFuel para Connect IQ 5.1 ou superior. O
mostrador usa imagem de fundo, desenho vetorial e fontes do sistema, com layout relativo
para telas redondas MIP e AMOLED de 218 a 454 pixels.

## Recursos

- hora grande, data e consumo de hidratação;
- três campos configuráveis, com calorias, temperatura e Body Battery por padrão;
- opções para passos, estresse, bateria, calorias e notificações;
- estilos Equilibrado, Foco em dados e Minimalista (Equilibrado e Foco em dados
  compartilham o mesmo visual nesta versão);
- cor de destaque configurável;
- editor nativo nos produtos recentes e App Settings nos demais;
- modo always-on AMOLED reduzido, com deslocamento contra burn-in;
- toque prolongado na hidratação para abrir o HydraFuel.

## Integração

Os aplicativos Connect IQ não compartilham `Application.Storage`. O HydraFuel
publica consumo/meta por `HYDRA` e cafeína consumida no dia por `CAFFEINE`;
esta watch face assina as duas complications privadas. A cafeína não está
disponível nos campos configuráveis desta versão. Ambos devem ser compilados e
instalados com a mesma developer key.

Depois de instalar os dois aplicativos, abra o HydraFuel uma vez para publicar
as complications. Até a primeira publicação, a watchface mostra `-- ml`;
um `0 ml` exibido sempre foi publicado explicitamente pelo HydraFuel.

## Compilar

No diretório `watchface`:

```bash
monkeyc -f monkey.jungle -d fr165 \
  -o bin/HydraFuelFace-fr165.prg \
  -y ~/.Garmin/ConnectIQ/Keys/developer_key.der -w
```

Para testar a ponte no VS Code, use a configuração **Run Complication Apps** e
selecione a pasta raiz como publisher e `watchface` como subscriber.

## Testes

Os testes automatizados cobrem formatação de calorias, hidratação indisponível
versus zero, unidades de temperatura, limites de progresso e conversão de
valores numéricos. A compilação prepara o pacote; `monkeydo` executa os testes.

```bash
monkeyc -f monkey.jungle -d fr165 \
  -o bin/HydraFuelFaceTests-fr165.prg \
  -y ~/.Garmin/ConnectIQ/Keys/developer_key.der -t -w
monkeydo bin/HydraFuelFaceTests-fr165.prg fr165 -t
```

Como teste de integração, abra o HydraFuel, registre uma bebida e volte à
watchface no mesmo minuto: o consumo deve atualizar ao retornar. Esse cenário,
a aparência e o modo always-on precisam de validação no simulador ou relógio.
