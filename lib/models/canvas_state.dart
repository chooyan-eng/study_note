import 'draw_object.dart';

class CanvasState {
  final List<DrawObject> objects;

  const CanvasState({this.objects = const []});

  CanvasState copyWith({List<DrawObject>? objects}) {
    return CanvasState(objects: objects ?? this.objects);
  }
}
