(:background)
class PersonalMessages {
    static function reminderMessages(level) {
        if (level == 1) {
            return [
                "Amor, um golinho de água 💧",
                "Amor, bora dar uma hidratada?",
                "Água, amorzinho 💙",
                "Amor, antes do próximo café: água 😂",
                "Amor, pausa de um minutinho pra água? 💧",
                "Garrafinha na mão, amor 😄💧"
            ];
        }
        if (level == 2) {
            return [
                "Amor, estou vendo que você não está tomando água 👀",
                "Você não é um cacto 🌵😂 Bebe água.",
                "Linda… cadê essa garrafinha? 😂",
                "Ei atleta, água também faz parte do treino.",
                "Dani, seu Garmin está mandando você beber água. Eu só concordo 😂",
                "Dani, hidratação atrasada: bora recuperar 💧"
            ];
        }
        if (level == 3) {
            return [
                "AMORRR 😂💧 vai beber água!",
                "Daniela! Seu Garmin está preocupado com essa garrafinha parada 😂",
                "Estou oficialmente ativando o modo namorado chato: BEBE ÁGUA 😂❤️",
                "Você não virou um cacto desde a última notificação 🌵😂",
                "Seu namorado programou isso justamente porque sabia que você ia esquecer 😂💧",
                "Alerta do namorado e do Garmin: água agora 😂💧"
            ];
        }
        return ["Amor, um golinho de água 💧"];
    }

    static function celebrationMessages() {
        return [
            "Agora simmmm 😂💧❤️",
            "Boa, amor! Meta do dia atingida!",
            "Sabia que você conseguia 😂❤️",
            "Cacto oficialmente cancelado 🌵❌😂",
            "Assinado: seu namorado e agora também seu fiscal de hidratação 😂💧"
        ];
    }
}
