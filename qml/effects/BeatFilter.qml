import QtQuick 2.0

import at.cb.beatlib 1.0

DirectForm2Filter {
    //2nd order butterworth lowpass for rhythm beat detection
    data: ({
             order: 2,
             sosMatrix: [
               [1, 1, 0, 1, -0.9858529555693972, 0]
             ],
             scaleValues: [0.0070735222153014]
           })
}
