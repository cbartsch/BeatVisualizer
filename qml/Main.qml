import Felgo 3.0
import QtQuick 2.0
import Qt.labs.settings 1.1

import at.cb.beatlib 1.0
import "effects"

App {
  property string audioFileName: ""
  readonly property bool hasAudioFile: !!audioFileName

  property int currentFilterIndex: 0
  readonly property var beatFilters: [null, bassBeatfilter, melodyBeatFilter]
  readonly property var beatFilterNames: ["None", "Bass", "Melody"]

  Settings {
    id: settings

    property var recentFiles: []
  }

  AudioFileSelector {
    id: audioFileSelector

    onAudioFileSelected: {
      audioFileName = fileName

      settings.recentFiles = [fileName].concat(settings.recentFiles.slice(0, 4))
    }
  }

  MP3Decoder {
    id: mp3Decoder

    effect: MultiEffect {
      effects: [beatDetector, volumeDetector]
    }
  }

  VolumeDetector {
    id: volumeDetector

    //1Hz 6th order butterworth lowpass
    data: ({
             order: 6,
             sosMatrix: [
               [1, 2, 1, 1, -1.9999262314904516, 0.9999262517890731],
               [1, 2, 1, 1, -1.9997985087109691, 0.9997985290082943],
               [1, 2, 1, 1, -1.9997247753578935, 0.9997247956544703]
             ],
             scaleValues: [
               0.0000000050746553,
               0.0000000050743313,
               0.0000000050741442
             ]
           })

    updateIntervalMs: 100
    filterDelayMs: 1000 / 1 //1s / fC = delay at fC
    startTime: mp3Decoder.startTime
  }

  MelodyBeatFilter {
    id: melodyBeatFilter
    // highpass filter for melody beat detection
  }

  BassBeatFilter {
    id: bassBeatfilter
    // lowpass filter for bass/rhythm beat detection
  }

  BeatDetector {
    id: beatDetector

    preEffect: beatFilters[currentFilterIndex]
    envelopeDetector: EnvelopeFilter { }

    volumeDetector: volumeDetector

    minTimeDistanceMs: 200
    beatHalfLifeTimeMs: 500

    onBeatDetected: {
      var beatTimeMs = sampleIndex / mp3Decoder.sampleRate * 1000
      var playTimeMs = new Date().getTime() - mp3Decoder.startTime
      var timeDiffMs = beatTimeMs - playTimeMs

      console.log("beat", envValue, diffValue, volume, timeDiffMs)

      if(timeDiffMs > 0) {
        animLineC.createObject(animRow, {
                                            timeDiffMs: timeDiffMs,
                                            intensity: diffValue / 2,
                                            loudness: envValue / maxValue,
                                            volume: volume
                                          })
      }
    }
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
        height: visible ? dp(100) : 0
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

            property real timeDiffMs: 0
            property real intensity: 0
            property real loudness: 0
            property real volume: 0

            readonly property real animDurationMs: 1000

            color: Qt.rgba(volume * 2, 0, 0, 1)
            width: dp(50) * loudness
            height: parent.height * Math.min(intensity / 2, 1)
            x: -width
            anchors.bottom: parent.bottom

            PropertyAnimation on x {
              id: xAnim
              running: true
              from: -(animRow.width / 2) * (animLine.timeDiffMs / (animLine.animDurationMs / 2) + 0.5)
              to: animRow.width
              duration: animLine.animDurationMs / 2 + animLine.timeDiffMs

              onRunningChanged: if(!running) animLine.destroy()
            }

            Connections {
              target: mp3Decoder
              onRunningChanged: if(!mp3Decoder.running) animLine.destroy()
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

          Repeater {
            model: settings.recentFiles

            SimpleRow {
              text: readableFileName(modelData)
              visible: !hasAudioFile
              textItem.maximumLineCount: 5
              textItem.wrapMode: Text.WrapAtWordBoundaryOrAnywhere

              onSelected: audioFileName = modelData
            }
          }

          SimpleRow {
            text: "Clear recents"
            visible: !hasAudioFile && settings.recentFiles.length > 0

            onSelected: settings.recentFiles = []
          }

          SimpleRow {
            text: "Close file"
            visible: hasAudioFile
            enabled: mp3Decoder.idle
            textItem.color: enabled ? "black" : "grey"

            onSelected: audioFileName = ""
          }

          SimpleRow {
            id: fileNameRow
            text: audioFileName ? "File:" : "No file selected"
            detailText: readableFileName(audioFileName)
            enabled: false
            visible: hasAudioFile
          }

          SimpleRow {
            text: "Beat detection filter: " + beatFilterNames[currentFilterIndex]
            visible: hasAudioFile && mp3Decoder.idle

            onSelected: currentFilterIndex = (currentFilterIndex + 1) % beatFilters.length
          }

          SimpleRow {
            text: "Play file"
            visible: hasAudioFile && mp3Decoder.idle

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

          SimpleRow {
            text: "Stopping..."
            visible: mp3Decoder.stopping
            enabled: false
            textItem.color: "grey"
          }
        }
      }
    }
  }

  function readableFileName(fileName) {
    return decodeURIComponent(fileUtils.cropPathAndKeepFilename(fileName))
  }
}
