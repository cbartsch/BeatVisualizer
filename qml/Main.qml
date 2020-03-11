import Felgo 3.0
import QtQuick 2.0

import at.cb.beatlib 1.0

App {
  property string audioFileName: ""
  readonly property bool hasAudioFile: !!audioFileName

  DirectForm2Filter {
    id: envelopeDetector

    data: ({
             order: 8,
             sosMatrix: [
               [1, 2, 1, 1, -1.999582010463876, 0.999583152065339],
               [1, 2, 1, 1, -1.998812233343328, 0.998813374505309],
               [1, 2, 1, 1, -1.998223471725322, 0.998224612551167],
               [1, 2, 1, 1, -1.997904980861054, 0.997906121505067]
             ],
             scaleValues: [
               0.000000285400366,
               0.000000285290495,
               0.000000285206461,
               0.000000285161003
             ]
           })
  }

  VolumeDetector {
    id: volumeDetector

    //1Hz 6th order butterworth lowpass
    data: ({
             order: 6,
             sosMatrix: [
               [1.0000000000000000, 2.0000000000000000, 1.0000000000000000, 1.0000000000000000, -1.9999262314904516, 0.9999262517890731],
               [1.0000000000000000, 2.0000000000000000, 1.0000000000000000, 1.0000000000000000, -1.9997985087109691, 0.9997985290082943],
               [1.0000000000000000, 2.0000000000000000, 1.0000000000000000, 1.0000000000000000, -1.9997247753578935, 0.9997247956544703]
             ],
             scaleValues: [0.0000000050746553, 0.0000000050743313, 0.0000000050741442]
           })

    updateIntervalMs: 100
    filterDelayMs: 1000 / 1 //1s / fC = delay at fC
    startTime: mp3Decoder.startTime
  }

  BeatDetector {
    id: beatDetector

    envelopeDetector: envelopeDetector
    volumeDetector: volumeDetector

    minTimeDistanceMs: 100
    beatHalfLifeTimeMs: 500

    onBeatDetected: {
      var beatTimeMs = sampleIndex / mp3Decoder.sampleRate * 1000
      var playTimeMs = new Date().getTime() - mp3Decoder.startTime
      var timeDiffMs = beatTimeMs - playTimeMs
      var startTimeMs = timeDiffMs - 500

      console.log("beat", envValue, diffValue, volume, timeDiffMs)

      if(startTimeMs > 0) {
        animLineC.createObject(animRow, {
                                 startTimeMs: timeDiffMs,
                                 intensity: diffValue / 2,
                                 loudness: envValue / maxValue,
                                 volume: volume
                               })
      }
    }
  }

  AudioFileSelector {
    id: audioFileSelector

    onAudioFileSelected: audioFileName = fileName
  }

  MP3Decoder {
    id: mp3Decoder

    effect: MultiEffect {
      effects: [beatDetector, volumeDetector]
    }

    onMetaDataChanged: console.log("meta data changed", metaData)
  }

  NavigationStack {

    Page {
      title: qsTr("BeatVisualizer")

      Rectangle {
        id: animRow

        property real v: volumeDetector.volume * 2
        property real c: 0.9 - v * 0.4

        anchors.bottom: parent.bottom
        width: parent.width
        height: dp(80)
        color: Qt.rgba(c, c, c, 1)
        visible: mp3Decoder.running

        Behavior on color {
          PropertyAnimation {
            duration: 200
          }
        }

        Rectangle {
          color: Qt.rgba(animRow.v, 0, 0, 1)

          width: dp(2)
          height: parent.height
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Component {
          id: animLineC

          Rectangle {
            id: animLine

            property real startTimeMs: 0
            property real intensity: 0
            property real loudness: 0
            property real volume: 0

            color: Qt.rgba(volume * 2, 0, 0, 1)
            width: dp(50) * loudness
            height: parent.height * Math.min(intensity / 2, 1)
            x: -width
            anchors.bottom: parent.bottom

            Timer {
              interval: animLine.startTimeMs
              running: true
              repeat: false
              onTriggered: xAnim.start()
            }

            PropertyAnimation on x {
              id: xAnim
              running: false
              to: animRow.width
              duration: 1000

              onRunningChanged: if(!running) animLine.destroy()
            }
          }
        }
      }

      AppFlickable {
        id: flickable
        anchors.top: parent.top
        anchors.bottom: animRow.top
        width: parent.width
        contentHeight: contentCol.height

        Column {
          id: contentCol
          width: parent.width

          SimpleRow {
            text: "Open audio file"
            visible: !hasAudioFile

            onSelected: audioFileSelector.selectAudioFile()
          }

          SimpleRow {
            text: "Close file"
            visible: hasAudioFile
            enabled: !mp3Decoder.running
            textItem.color: enabled ? "black" : "grey"

            onSelected: audioFileName = ""
          }

          SimpleRow {
            id: fileNameRow
            text: audioFileName ? "File:" : "No file selected"
            detailText: audioFileName
            enabled: false
            visible: hasAudioFile
            textItem.color: enabled ? "black" : "grey"
          }

          SimpleRow {
            text: "Play file"
            visible: hasAudioFile && !mp3Decoder.running

            onSelected: {
              var stream = audioFileSelector.openAudioStream(audioFileName)
              mp3Decoder.play(stream)
            }
          }

          SimpleRow {
            visible: mp3Decoder.running

            text: mp3Decoder.running
                  ? mp3Decoder.metaData
                    ? (mp3Decoder.metaData.title || "(Unknown Title)")
                    : "Playing"
                  : ""

            detailText: mp3Decoder.running && mp3Decoder.metaData
                        ? (mp3Decoder.metaData.artist || "(Unknown Artist)") +
                          " - " +
                          (mp3Decoder.metaData.album || "(Unknown Album)")
                        : ""

            enabled: false
          }

          SimpleRow {
            text: "Stop playback"
            visible: mp3Decoder.running

            onSelected: mp3Decoder.stop()
          }
        }
      }
    }
  }
}
