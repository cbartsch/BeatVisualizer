import QtQuick 2.0

import at.cb.beatlib 1.0

DirectForm2Filter {
    //250Hz 8th order butterworth lowpass for rhythm/bass beat detection
    data: ({
            order: 8,
            sosMatrix: [
                [1, 2, 1, 1, -1.9912417315447684, 0.9916965538156610],
                [1, 2, 1, 1, -1.9760824443400362, 0.9765338040572257],
                [1, 2, 1, 1, -1.9646350579658782, 0.9650838029697538],
                [1, 2, 1, 1, -1.9584949163390089, 0.9589422588646648]
            ],
            scaleValues: [
               0.0001137055677232,
               0.0001128399292974,
               0.0001121862509689,
               0.0001118356314140
             ]
        })
}
