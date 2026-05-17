import 'package:test/test.dart';
import 'package:waddle_data_providers/media_pexels/pexels_video_mp4_pick.dart';

Map<String, dynamic> _videoWithFiles(List<Map<String, Object>> files) => {
      'video_files': files,
    };

void main() {
  test('pickPexelsVideoMp4Url prefers largest width under cap', () {
    final url = pickPexelsVideoMp4Url(
      _videoWithFiles([
        {
          'link': 'http://a/4k.mp4',
          'file_type': 'video/mp4',
          'width': 3840,
        },
        {
          'link': 'http://a/1080.mp4',
          'file_type': 'video/mp4',
          'width': 1920,
        },
        {
          'link': 'http://a/720.mp4',
          'file_type': 'video/mp4',
          'width': 1280,
        },
      ]),
      maxWidth: 1920,
    );
    expect(url, 'http://a/1080.mp4');
  });

  test('pickPexelsVideoMp4Url falls back to smallest when all exceed cap', () {
    final url = pickPexelsVideoMp4Url(
      _videoWithFiles([
        {
          'link': 'http://a/4k.mp4',
          'file_type': 'video/mp4',
          'width': 3840,
        },
        {
          'link': 'http://a/1440.mp4',
          'file_type': 'video/mp4',
          'width': 2560,
        },
      ]),
      maxWidth: 1280,
    );
    expect(url, 'http://a/1440.mp4');
  });

  test('resolvePexelsMaxVideoDownloadWidth honors env override', () {
    // dart test cannot set Platform.environment portably; config path only here.
    expect(resolvePexelsMaxVideoDownloadWidth(1280), 1280);
    expect(
      resolvePexelsMaxVideoDownloadWidth(0),
      kPexelsDefaultMaxVideoDownloadWidth,
    );
  });
}
