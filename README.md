This is a fork of SCXIB whose main point is to extend the functionality to the point that its
no longer needed to edit the resulting generated code, and thus the Nib file can be edited
at will.

One main change from the original SCXIB - this version always creates an SC.Page, which contains
any all views that are embedded in the Nib file.  You may assign names to each view within the page by
editing an object's Label in IB (within the identity metadata of the object)

## How to use SCXIB

### XIB to JavaScript

Transform a XIB file into a JavaScript file for your SproutCore application
using a command line tool:
    ./bin/scxib -namespace DemoApp -page mainPage apps/demo_app/resources/MainPage.xib

Some useful options:

  - -sc_require {module_name}  - embeds an sc_require directive in front of class definition.  Can be used more than once
  - -debug - dumps the XSLT generated code before prettyfication - useful for trying to solve coding errors

## Requirements

  - Interface Builder for XCode 3.2.x or 4.x
  - SproutCore

Make sure to build the native hex extensions plugin before running scxib.  Make on the current directory should be sufficient.

## Current Class Mappings

  - NSWindow -> SC.MainPane
  - NSPanel -> SC.Panel
  - NSView -> SC.View
  - NSCustomView -> your app's custom view name
  - NSLabel -> SC.LabelView
  - NSTextField -> SC.TextFieldView
  - NSSplitView -> SC.SplitView
  - IKImageView -> SC.ImageView
  - NSImageView -> SC.ImageView
  - NSCheckBox -> SC.CheckBoxView
  - NSButton -> SC.ButtonView
  - NSPopUpButton -> SC.SelectFieldView
  - NSSlider -> SC.SliderView
  - NSProgressIndicator -> SC.ProgressView (Preliminary, only indeterminate and
    minimum value / current value are being ignored)
  - NSSegmentedControl -> SC.SegmentedView
  - NSCollectionView -> SC.ListView
  - NSOutlineView -> SC.SourceListView
  - NSScrollView -> SC.ScrollView
  - NSWebView -> SC.WebView
  - NSMatrix -> SC.RadioView
  - NSTabView -> SC.TabView
  - NSTableView -> SC.TableView (Requires Sproutcore 1.4+)
  - NSBox Horizontal/Vertical -> SC.SeparatorView:layoutDirection SC.LAYOUT\_HORIZONTAL/SC.LAYOUT\_VERTICAL
  - NSMenu -> SC.MenuPane

## Class Documentation
If you want to bind ListViews or TableViews to objects, you need to set a
couple of different runtime parameters, as these bindings are currently not
realized using the IB bindings tab. Here's a documentation of specific
attributes for these objects:

### NSCollectionView / SC.ListView:
- exampleView: Can either be set as a runtime parameter, or subclassing an
  NSCollectionViewItem to the SproutCore item name.

### NSTableView / SC.TableView:
- Support for NSTableView is preliminary. Many of the IB Flags aren't supported
  yet.
- exampleView: Mandatory. Set it as a runtime parameter. You have to set this, even if you
  did not subclass in SC: exampleView: SC.TableRowView
- row Key: The 'Identifier' field in the 'Table Column Attributes' Tab of the IB
  Inspector
- row Label: The 'Title' field in the 'Table Column Attributes' Tab of the IB
  Inspector 

