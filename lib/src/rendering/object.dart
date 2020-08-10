// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:hermit/animation.dart';
import 'package:hermit/foundation.dart';
import 'package:hermit/painting.dart';

import 'binding.dart';

export 'package:hermit/foundation.dart' show FlutterError, InformationCollector, DiagnosticsNode, ErrorSummary, ErrorDescription, ErrorHint, DiagnosticsProperty, StringProperty, DoubleProperty, EnumProperty, FlagProperty, IntProperty, DiagnosticPropertiesBuilder;
export 'package:hermit/painting.dart';

/// Base class for data associated with a [RenderObject] by its parent.
///
/// Some render objects wish to store data on their children, such as their
/// input parameters to the parent's layout algorithm or their position relative
/// to other children.
class ParentData {
  /// Called when the RenderObject is removed from the tree.
  @protected
  @mustCallSuper
  void detach() { }

  @override
  String toString() => '<none>';
}

/// Signature for a function that is called for each [RenderObject].
///
/// Used by [RenderObject.visitChildren] and [RenderObject.visitChildrenForSemantics].
typedef RenderObjectVisitor = void Function(RenderObject child);

/// The pipeline owner manages the rendering pipeline.
///
/// The pipeline owner provides an interface for driving the rendering pipeline
/// and stores the state about which render objects have requested to be visited
/// in each stage of the pipeline. To flush the pipeline, call the following
/// functions in order:
///
/// 1. [flushLayout] updates any render objects that need to compute their
///    layout. During this phase, the size and position of each render
///    object is calculated. Render objects might dirty their painting or
///    compositing state during this phase.
/// 2. [flushCompositingBits] updates any render objects that have dirty
///    compositing bits. During this phase, each render object learns whether
///    any of its children require compositing. This information is used during
///    the painting phase when selecting how to implement visual effects such as
///    clipping. If a render object has a composited child, its needs to use a
///    [Layer] to create the clip in order for the clip to apply to the
///    composited child (which will be painted into its own [Layer]).
/// 3. [flushPaint] visits any render objects that need to paint. During this
///    phase, render objects get a chance to record painting commands into
///    [PictureLayer]s and construct other composited [Layer]s.
/// 4. Finally, if semantics are enabled, [flushSemantics] will compile the
///    semantics for the render objects. This semantic information is used by
///    assistive technology to improve the accessibility of the render tree.
///
/// The [RendererBinding] holds the pipeline owner for the render objects that
/// are visible on screen. You can create other pipeline owners to manage
/// off-screen objects, which can flush their pipelines independently of the
/// on-screen render objects.
class PipelineOwner {
  /// Creates a pipeline owner.
  ///
  /// Typically created by the binding (e.g., [RendererBinding]), but can be
  /// created separately from the binding to drive off-screen render objects
  /// through the rendering pipeline.
  PipelineOwner({
    this.onNeedVisualUpdate,
    this.onSemanticsOwnerCreated,
    this.onSemanticsOwnerDisposed,
  });

  /// Called when a render object associated with this pipeline owner wishes to
  /// update its visual appearance.
  ///
  /// Typical implementations of this function will schedule a task to flush the
  /// various stages of the pipeline. This function might be called multiple
  /// times in quick succession. Implementations should take care to discard
  /// duplicate calls quickly.
  final VoidCallback onNeedVisualUpdate;

  /// Called whenever this pipeline owner creates a semantics object.
  ///
  /// Typical implementations will schedule the creation of the initial
  /// semantics tree.
  final VoidCallback onSemanticsOwnerCreated;

  /// Called whenever this pipeline owner disposes its semantics owner.
  ///
  /// Typical implementations will tear down the semantics tree.
  final VoidCallback onSemanticsOwnerDisposed;

  /// Calls [onNeedVisualUpdate] if [onNeedVisualUpdate] is not null.
  ///
  /// Used to notify the pipeline owner that an associated render object wishes
  /// to update its visual appearance.
  void requestVisualUpdate() {
    if (onNeedVisualUpdate != null)
      onNeedVisualUpdate();
  }

  /// The unique object managed by this pipeline that has no parent.
  ///
  /// This object does not have to be a [RenderObject].
  AbstractNode get rootNode => _rootNode;
  AbstractNode _rootNode;
  set rootNode(AbstractNode value) {
    if (_rootNode == value)
      return;
    _rootNode?.detach();
    _rootNode = value;
    _rootNode?.attach(this);
  }
}

/// An object in the render tree.
///
/// The [RenderObject] class hierarchy is the core of the rendering
/// library's reason for being.
///
/// [RenderObject]s have a [parent], and have a slot called [parentData] in
/// which the parent [RenderObject] can store child-specific data, for example,
/// the child position. The [RenderObject] class also implements the basic
/// layout and paint protocols.
///
/// The [RenderObject] class, however, does not define a child model (e.g.
/// whether a node has zero, one, or more children). It also doesn't define a
/// coordinate system (e.g. whether children are positioned in Cartesian
/// coordinates, in polar coordinates, etc) or a specific layout protocol (e.g.
/// whether the layout is width-in-height-out, or constraint-in-size-out, or
/// whether the parent sets the size and position of the child before or after
/// the child lays out, etc; or indeed whether the children are allowed to read
/// their parent's [parentData] slot).
///
/// The [RenderBox] subclass introduces the opinion that the layout
/// system uses Cartesian coordinates.
///
/// ## Writing a RenderObject subclass
///
/// In most cases, subclassing [RenderObject] itself is overkill, and
/// [RenderBox] would be a better starting point. However, if a render object
/// doesn't want to use a Cartesian coordinate system, then it should indeed
/// inherit from [RenderObject] directly. This allows it to define its own
/// layout protocol by using a new subclass of [Constraints] rather than using
/// [BoxConstraints], and by potentially using an entirely new set of objects
/// and values to represent the result of the output rather than just a [Size].
/// This increased flexibility comes at the cost of not being able to rely on
/// the features of [RenderBox]. For example, [RenderBox] implements an
/// intrinsic sizing protocol that allows you to measure a child without fully
/// laying it out, in such a way that if that child changes size, the parent
/// will be laid out again (to take into account the new dimensions of the
/// child). This is a subtle and bug-prone feature to get right.
///
/// Most aspects of writing a [RenderBox] apply to writing a [RenderObject] as
/// well, and therefore the discussion at [RenderBox] is recommended background
/// reading. The main differences are around layout and hit testing, since those
/// are the aspects that [RenderBox] primarily specializes.
///
/// ### Layout
///
/// A layout protocol begins with a subclass of [Constraints]. See the
/// discussion at [Constraints] for more information on how to write a
/// [Constraints] subclass.
///
/// The [performLayout] method should take the [constraints], and apply them.
/// The output of the layout algorithm is fields set on the object that describe
/// the geometry of the object for the purposes of the parent's layout. For
/// example, with [RenderBox] the output is the [RenderBox.size] field. This
/// output should only be read by the parent if the parent specified
/// `parentUsesSize` as true when calling [layout] on the child.
///
/// Anytime anything changes on a render object that would affect the layout of
/// that object, it should call [markNeedsLayout].
///
/// ### Hit Testing
///
/// Hit testing is even more open-ended than layout. There is no method to
/// override, you are expected to provide one.
///
/// The general behavior of your hit-testing method should be similar to the
/// behavior described for [RenderBox]. The main difference is that the input
/// need not be an [Offset]. You are also allowed to use a different subclass of
/// [HitTestEntry] when adding entries to the [HitTestResult]. When the
/// [handleEvent] method is called, the same object that was added to the
/// [HitTestResult] will be passed in, so it can be used to track information
/// like the precise coordinate of the hit, in whatever coordinate system is
/// used by the new layout protocol.
///
/// ### Adapting from one protocol to another
///
/// In general, the root of a Flutter render object tree is a [RenderView]. This
/// object has a single child, which must be a [RenderBox]. Thus, if you want to
/// have a custom [RenderObject] subclass in the render tree, you have two
/// choices: you either need to replace the [RenderView] itself, or you need to
/// have a [RenderBox] that has your class as its child. (The latter is the much
/// more common case.)
///
/// This [RenderBox] subclass converts from the box protocol to the protocol of
/// your class.
///
/// In particular, this means that for hit testing it overrides
/// [RenderBox.hitTest], and calls whatever method you have in your class for
/// hit testing.
///
/// Similarly, it overrides [performLayout] to create a [Constraints] object
/// appropriate for your class and passes that to the child's [layout] method.
///
/// ### Layout interactions between render objects
///
/// In general, the layout of a render object should only depend on the output of
/// its child's layout, and then only if `parentUsesSize` is set to true in the
/// [layout] call. Furthermore, if it is set to true, the parent must call the
/// child's [layout] if the child is to be rendered, because otherwise the
/// parent will not be notified when the child changes its layout outputs.
///
/// It is possible to set up render object protocols that transfer additional
/// information. For example, in the [RenderBox] protocol you can query your
/// children's intrinsic dimensions and baseline geometry. However, if this is
/// done then it is imperative that the child call [markNeedsLayout] on the
/// parent any time that additional information changes, if the parent used it
/// in the last layout phase. For an example of how to implement this, see the
/// [RenderBox.markNeedsLayout] method. It overrides
/// [RenderObject.markNeedsLayout] so that if a parent has queried the intrinsic
/// or baseline information, it gets marked dirty whenever the child's geometry
/// changes.
abstract class RenderObject extends AbstractNode with DiagnosticableTreeMixin {
  /// Cause the entire subtree rooted at the given [RenderObject] to be marked
  /// dirty for layout, paint, etc, so that the effects of a hot reload can be
  /// seen, or so that the effect of changing a global debug flag (such as
  /// [debugPaintSizeEnabled]) can be applied.
  ///
  /// This is called by the [RendererBinding] in response to the
  /// `ext.flutter.reassemble` hook, which is used by development tools when the
  /// application code has changed, to cause the widget tree to pick up any
  /// changed implementations.
  ///
  /// This is expensive and should not be called except during development.
  ///
  /// See also:
  ///
  ///  * [BindingBase.reassembleApplication]
  void reassemble() {
    visitChildren((RenderObject child) {
      child.reassemble();
    });
  }

  // LAYOUT

  /// Data for use by the parent render object.
  ///
  /// The parent data is used by the render object that lays out this object
  /// (typically this object's parent in the render tree) to store information
  /// relevant to itself and to any other nodes who happen to know exactly what
  /// the data means. The parent data is opaque to the child.
  ///
  ///  * The parent data field must not be directly set, except by calling
  ///    [setupParentData] on the parent node.
  ///  * The parent data can be set before the child is added to the parent, by
  ///    calling [setupParentData] on the future parent node.
  ///  * The conventions for using the parent data depend on the layout protocol
  ///    used between the parent and child. For example, in box layout, the
  ///    parent data is completely opaque but in sector layout the child is
  ///    permitted to read some fields of the parent data.
  ParentData parentData;

  /// Override to setup parent data correctly for your children.
  ///
  /// You can call this function to set up the parent data for child before the
  /// child is added to the parent's child list.
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! ParentData)
      child.parentData = ParentData();
  }

  /// Called by subclasses when they decide a render object is a child.
  ///
  /// Only for use by subclasses when changing their child lists. Calling this
  /// in other cases will lead to an inconsistent tree and probably cause crashes.
  @override
  void adoptChild(RenderObject child) {
    assert(child != null);
    setupParentData(child);
    super.adoptChild(child);
  }

  /// Called by subclasses when they decide a render object is no longer a child.
  ///
  /// Only for use by subclasses when changing their child lists. Calling this
  /// in other cases will lead to an inconsistent tree and probably cause crashes.
  @override
  void dropChild(RenderObject child) {
    assert(child != null);
    assert(child.parentData != null);
    child.parentData.detach();
    child.parentData = null;
    super.dropChild(child);
  }

  /// Calls visitor for each immediate child of this render object.
  ///
  /// Override in subclasses with children and call the visitor for each child.
  void visitChildren(RenderObjectVisitor visitor) { }

  /// The object responsible for creating this render object.
  ///
  /// Used in debug messages.
  dynamic debugCreator;

  /// The render object that is actively computing layout.
  ///
  /// Only valid when asserts are enabled. In release builds, always returns
  /// null.
  static RenderObject get debugActiveLayout => _debugActiveLayout;
  static RenderObject _debugActiveLayout;

  /// Whether the parent render object is permitted to use this render object's
  /// size.
  ///
  /// Determined by the `parentUsesSize` parameter to [layout].
  ///
  /// Only valid when asserts are enabled. In release builds, always returns
  /// null.
  bool get debugCanParentUseSize => _debugCanParentUseSize;
  bool _debugCanParentUseSize;

  @override
  PipelineOwner get owner => super.owner as PipelineOwner;

  /// Returns a human understandable name.
  @override
  String toStringShort() {
    String header = describeIdentity(this);
    if (!attached)
      header += ' DETACHED';
    return header;
  }

  @override
  String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) => toStringShort();

  /// Returns a description of the tree rooted at this node.
  /// If the prefix argument is provided, then every line in the output
  /// will be prefixed by that string.
  @override
  String toStringDeep({
    String prefixLineOne = '',
    String prefixOtherLines = '',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    RenderObject debugPreviousActiveLayout;
    assert(() {
      debugPreviousActiveLayout = _debugActiveLayout;
      _debugActiveLayout = null;
      return true;
    }());
    final String result = super.toStringDeep(
      prefixLineOne: prefixLineOne,
      prefixOtherLines: prefixOtherLines,
      minLevel: minLevel,
    );
    assert(() {
      _debugActiveLayout = debugPreviousActiveLayout;
      return true;
    }());
    return result;
  }

  /// Returns a one-line detailed description of the render object.
  /// This description is often somewhat long.
  ///
  /// This includes the same information for this RenderObject as given by
  /// [toStringDeep], but does not recurse to any children.
  @override
  String toStringShallow({
    String joiner = ', ',
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
  }) {
    RenderObject debugPreviousActiveLayout;
    assert(() {
      debugPreviousActiveLayout = _debugActiveLayout;
      _debugActiveLayout = null;
      return true;
    }());
    final String result = super.toStringShallow(joiner: joiner, minLevel: minLevel);
    assert(() {
      _debugActiveLayout = debugPreviousActiveLayout;
      return true;
    }());
    return result;
  }

  @protected
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<dynamic>('creator', debugCreator, defaultValue: null, level: DiagnosticLevel.debug));
    properties.add(DiagnosticsProperty<ParentData>('parentData', parentData, tooltip: _debugCanParentUseSize == true ? 'can use size' : null, missingIfNull: true));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() => <DiagnosticsNode>[];

  /// Attempt to make (a portion of) this or a descendant [RenderObject] visible
  /// on screen.
  ///
  /// If `descendant` is provided, that [RenderObject] is made visible. If
  /// `descendant` is omitted, this [RenderObject] is made visible.
  ///
  /// The optional `rect` parameter describes which area of that [RenderObject]
  /// should be shown on screen. If `rect` is null, the entire
  /// [RenderObject] (as defined by its [paintBounds]) will be revealed. The
  /// `rect` parameter is interpreted relative to the coordinate system of
  /// `descendant` if that argument is provided and relative to this
  /// [RenderObject] otherwise.
  ///
  /// The `duration` parameter can be set to a non-zero value to bring the
  /// target object on screen in an animation defined by `curve`.
  void showOnScreen({
    RenderObject descendant,
    Rect rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (parent is RenderObject) {
      final RenderObject renderParent = parent as RenderObject;
      renderParent.showOnScreen(
        descendant: descendant ?? this,
        rect: rect,
        duration: duration,
        curve: curve,
      );
    }
  }

  /// Adds a debug representation of a [RenderObject] optimized for including in
  /// error messages.
  ///
  /// The default [style] of [DiagnosticsTreeStyle.shallow] ensures that all of
  /// the properties of the render object are included in the error output but
  /// none of the children of the object are.
  ///
  /// You should always include a RenderObject in an error message if it is the
  /// [RenderObject] causing the failure or contract violation of the error.
  DiagnosticsNode describeForError(String name, { DiagnosticsTreeStyle style = DiagnosticsTreeStyle.shallow }) {
    return toDiagnosticsNode(name: name, style: style);
  }
}

/// Generic mixin for render objects with one child.
///
/// Provides a child model for a render object subclass that has
/// a unique child, which is accessible via the [child] getter.
///
/// This mixin is typically used to implement render objects created
/// in a [SingleChildRenderObjectWidget].
mixin RenderObjectWithChildMixin<ChildType extends RenderObject> on RenderObject {

  /// Checks whether the given render object has the correct [runtimeType] to be
  /// a child of this render object.
  ///
  /// Does nothing if assertions are disabled.
  ///
  /// Always returns true.
  bool debugValidateChild(RenderObject child) {
    assert(() {
      if (child is! ChildType) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'A $runtimeType expected a child of type $ChildType but received a '
            'child of type ${child.runtimeType}.'
          ),
          ErrorDescription(
            'RenderObjects expect specific types of children because they '
            'coordinate with their children during layout and paint. For '
            'example, a RenderSliver cannot be the child of a RenderBox because '
            'a RenderSliver does not understand the RenderBox layout protocol.',
          ),
          ErrorSpacer(),
          DiagnosticsProperty<dynamic>(
            'The $runtimeType that expected a $ChildType child was created by',
            debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          ErrorSpacer(),
          DiagnosticsProperty<dynamic>(
            'The ${child.runtimeType} that did not match the expected child type '
            'was created by',
            child.debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  ChildType _child;
  /// The render object's unique child
  ChildType get child => _child;
  set child(ChildType value) {
    if (_child != null)
      dropChild(_child);
    _child = value;
    if (_child != null)
      adoptChild(_child);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_child != null)
      _child.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    if (_child != null)
      _child.detach();
  }

  @override
  void redepthChildren() {
    if (_child != null)
      redepthChild(_child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_child != null)
      visitor(_child);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return child != null ? <DiagnosticsNode>[child.toDiagnosticsNode(name: 'child')] : <DiagnosticsNode>[];
  }
}

/// Parent data to support a doubly-linked list of children.
///
/// The children can be traversed using [nextSibling] or [previousSibling],
/// which can be called on the parent data of the render objects
/// obtained via [ContainerRenderObjectMixin.firstChild] or
/// [ContainerRenderObjectMixin.lastChild].
mixin ContainerParentDataMixin<ChildType extends RenderObject> on ParentData {
  /// The previous sibling in the parent's child list.
  ChildType previousSibling;
  /// The next sibling in the parent's child list.
  ChildType nextSibling;

  /// Clear the sibling pointers.
  @override
  void detach() {
    assert(previousSibling == null, 'Pointers to siblings must be nulled before detaching ParentData.');
    assert(nextSibling == null, 'Pointers to siblings must be nulled before detaching ParentData.');
    super.detach();
  }
}

/// Generic mixin for render objects with a list of children.
///
/// Provides a child model for a render object subclass that has a doubly-linked
/// list of children.
///
/// The [ChildType] specifies the type of the children (extending [RenderObject]),
/// e.g. [RenderBox].
///
/// [ParentDataType] stores parent container data on its child render objects.
/// It must extend [ContainerParentDataMixin], which provides the interface
/// for visiting children. This data is populated by
/// [RenderObject.setupParentData] implemented by the class using this mixin.
///
/// When using [RenderBox] as the child type, you will usually want to make use of
/// [RenderBoxContainerDefaultsMixin] and extend [ContainerBoxParentData] for the
/// parent data.
///
/// Moreover, this is a required mixin for render objects returned to [MultiChildRenderObjectWidget].
mixin ContainerRenderObjectMixin<ChildType extends RenderObject, ParentDataType extends ContainerParentDataMixin<ChildType>> on RenderObject {
  bool _debugUltimatePreviousSiblingOf(ChildType child, { ChildType equals }) {
    ParentDataType childParentData = child.parentData as ParentDataType;
    while (childParentData.previousSibling != null) {
      assert(childParentData.previousSibling != child);
      child = childParentData.previousSibling;
      childParentData = child.parentData as ParentDataType;
    }
    return child == equals;
  }
  bool _debugUltimateNextSiblingOf(ChildType child, { ChildType equals }) {
    ParentDataType childParentData = child.parentData as ParentDataType;
    while (childParentData.nextSibling != null) {
      assert(childParentData.nextSibling != child);
      child = childParentData.nextSibling;
      childParentData = child.parentData as ParentDataType;
    }
    return child == equals;
  }

  int _childCount = 0;
  /// The number of children.
  int get childCount => _childCount;

  /// Checks whether the given render object has the correct [runtimeType] to be
  /// a child of this render object.
  ///
  /// Does nothing if assertions are disabled.
  ///
  /// Always returns true.
  bool debugValidateChild(RenderObject child) {
    assert(() {
      if (child is! ChildType) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'A $runtimeType expected a child of type $ChildType but received a '
            'child of type ${child.runtimeType}.'
          ),
          ErrorDescription(
            'RenderObjects expect specific types of children because they '
            'coordinate with their children during layout and paint. For '
            'example, a RenderSliver cannot be the child of a RenderBox because '
            'a RenderSliver does not understand the RenderBox layout protocol.'
          ),
          ErrorSpacer(),
          DiagnosticsProperty<dynamic>(
            'The $runtimeType that expected a $ChildType child was created by',
            debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
          ErrorSpacer(),
          DiagnosticsProperty<dynamic>(
            'The ${child.runtimeType} that did not match the expected child type '
            'was created by',
            child.debugCreator,
            style: DiagnosticsTreeStyle.errorProperty,
          ),
        ]);
      }
      return true;
    }());
    return true;
  }

  ChildType _firstChild;
  ChildType _lastChild;
  void _insertIntoChildList(ChildType child, { ChildType after }) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    assert(childParentData.nextSibling == null);
    assert(childParentData.previousSibling == null);
    _childCount += 1;
    assert(_childCount > 0);
    if (after == null) {
      // insert at the start (_firstChild)
      childParentData.nextSibling = _firstChild;
      if (_firstChild != null) {
        final ParentDataType _firstChildParentData = _firstChild.parentData as ParentDataType;
        _firstChildParentData.previousSibling = child;
      }
      _firstChild = child;
      _lastChild ??= child;
    } else {
      assert(_firstChild != null);
      assert(_lastChild != null);
      assert(_debugUltimatePreviousSiblingOf(after, equals: _firstChild));
      assert(_debugUltimateNextSiblingOf(after, equals: _lastChild));
      final ParentDataType afterParentData = after.parentData as ParentDataType;
      if (afterParentData.nextSibling == null) {
        // insert at the end (_lastChild); we'll end up with two or more children
        assert(after == _lastChild);
        childParentData.previousSibling = after;
        afterParentData.nextSibling = child;
        _lastChild = child;
      } else {
        // insert in the middle; we'll end up with three or more children
        // set up links from child to siblings
        childParentData.nextSibling = afterParentData.nextSibling;
        childParentData.previousSibling = after;
        // set up links from siblings to child
        final ParentDataType childPreviousSiblingParentData = childParentData.previousSibling.parentData as ParentDataType;
        final ParentDataType childNextSiblingParentData = childParentData.nextSibling.parentData as ParentDataType;
        childPreviousSiblingParentData.nextSibling = child;
        childNextSiblingParentData.previousSibling = child;
        assert(afterParentData.nextSibling == child);
      }
    }
  }
  /// Insert child into this render object's child list after the given child.
  ///
  /// If `after` is null, then this inserts the child at the start of the list,
  /// and the child becomes the new [firstChild].
  void insert(ChildType child, { ChildType after }) {
    assert(child != this, 'A RenderObject cannot be inserted into itself.');
    assert(after != this, 'A RenderObject cannot simultaneously be both the parent and the sibling of another RenderObject.');
    assert(child != after, 'A RenderObject cannot be inserted after itself.');
    assert(child != _firstChild);
    assert(child != _lastChild);
    adoptChild(child);
    _insertIntoChildList(child, after: after);
  }

  /// Append child to the end of this render object's child list.
  void add(ChildType child) {
    insert(child, after: _lastChild);
  }

  /// Add all the children to the end of this render object's child list.
  void addAll(List<ChildType> children) {
    children?.forEach(add);
  }

  void _removeFromChildList(ChildType child) {
    final ParentDataType childParentData = child.parentData as ParentDataType;
    assert(_debugUltimatePreviousSiblingOf(child, equals: _firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: _lastChild));
    assert(_childCount >= 0);
    if (childParentData.previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = childParentData.nextSibling;
    } else {
      final ParentDataType childPreviousSiblingParentData = childParentData.previousSibling.parentData as ParentDataType;
      childPreviousSiblingParentData.nextSibling = childParentData.nextSibling;
    }
    if (childParentData.nextSibling == null) {
      assert(_lastChild == child);
      _lastChild = childParentData.previousSibling;
    } else {
      final ParentDataType childNextSiblingParentData = childParentData.nextSibling.parentData as ParentDataType;
      childNextSiblingParentData.previousSibling = childParentData.previousSibling;
    }
    childParentData.previousSibling = null;
    childParentData.nextSibling = null;
    _childCount -= 1;
  }

  /// Remove this child from the child list.
  ///
  /// Requires the child to be present in the child list.
  void remove(ChildType child) {
    _removeFromChildList(child);
    dropChild(child);
  }

  /// Remove all their children from this render object's child list.
  ///
  /// More efficient than removing them individually.
  void removeAll() {
    ChildType child = _firstChild;
    while (child != null) {
      final ParentDataType childParentData = child.parentData as ParentDataType;
      final ChildType next = childParentData.nextSibling;
      childParentData.previousSibling = null;
      childParentData.nextSibling = null;
      dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
    _childCount = 0;
  }

  /// Move the given `child` in the child list to be after another child.
  ///
  /// More efficient than removing and re-adding the child. Requires the child
  /// to already be in the child list at some position. Pass null for `after` to
  /// move the child to the start of the child list.
  void move(ChildType child, { ChildType after }) {
    assert(child != this);
    assert(after != this);
    assert(child != after);
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData as ParentDataType;
    if (childParentData.previousSibling == after)
      return;
    _removeFromChildList(child);
    _insertIntoChildList(child, after: after);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    ChildType child = _firstChild;
    while (child != null) {
      child.attach(owner);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    ChildType child = _firstChild;
    while (child != null) {
      child.detach();
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void redepthChildren() {
    ChildType child = _firstChild;
    while (child != null) {
      redepthChild(child);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    ChildType child = _firstChild;
    while (child != null) {
      visitor(child);
      final ParentDataType childParentData = child.parentData as ParentDataType;
      child = childParentData.nextSibling;
    }
  }

  /// The first child in the child list.
  ChildType get firstChild => _firstChild;

  /// The last child in the child list.
  ChildType get lastChild => _lastChild;

  /// The previous child before the given child in the child list.
  ChildType childBefore(ChildType child) {
    assert(child != null);
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData as ParentDataType;
    return childParentData.previousSibling;
  }

  /// The next child after the given child in the child list.
  ChildType childAfter(ChildType child) {
    assert(child != null);
    assert(child.parent == this);
    final ParentDataType childParentData = child.parentData as ParentDataType;
    return childParentData.nextSibling;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (firstChild != null) {
      ChildType child = firstChild;
      int count = 1;
      while (true) {
        children.add(child.toDiagnosticsNode(name: 'child $count'));
        if (child == lastChild)
          break;
        count += 1;
        final ParentDataType childParentData = child.parentData as ParentDataType;
        child = childParentData.nextSibling;
      }
    }
    return children;
  }
}

/// Variant of [FlutterErrorDetails] with extra fields for the rendering
/// library.
class FlutterErrorDetailsForRendering extends FlutterErrorDetails {
  /// Creates a [FlutterErrorDetailsForRendering] object with the given
  /// arguments setting the object's properties.
  ///
  /// The rendering library calls this constructor when catching an exception
  /// that will subsequently be reported using [FlutterError.onError].
  const FlutterErrorDetailsForRendering({
    dynamic exception,
    StackTrace stack,
    String library,
    DiagnosticsNode context,
    this.renderObject,
    InformationCollector informationCollector,
    bool silent = false,
  }) : super(
    exception: exception,
    stack: stack,
    library: library,
    context: context,
    informationCollector: informationCollector,
    silent: silent,
  );

  /// The RenderObject that was being processed when the exception was caught.
  final RenderObject renderObject;
}

/// A class that creates [DiagnosticsNode] by wrapping [RenderObject.debugCreator].
///
/// Attach a [DiagnosticsDebugCreator] into [FlutterErrorDetails.informationCollector]
/// when a [RenderObject.debugCreator] is available. This will lead to improved
/// error message.
class DiagnosticsDebugCreator extends DiagnosticsProperty<Object> {
  /// Create a [DiagnosticsProperty] with its [value] initialized to input
  /// [RenderObject.debugCreator].
  DiagnosticsDebugCreator(Object value)
    : assert(value != null),
      super(
        'debugCreator',
        value,
        level: DiagnosticLevel.hidden,
      );
}
