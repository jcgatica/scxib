<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:exsl="http://exslt.org/common"
                xmlns:str="http://exslt.org/strings"
                xmlns:hexConvert="http://kace.com/xslt/hexConvert"
                extension-element-prefixes="exsl str hexConvert"
                version="1.0">

    <xsl:output method="text" media-type="text" omit-xml-declaration="yes"/>

    <xsl:param name="namespace" />
    <xsl:param name="pageName" />
    <xsl:param name="resourcesPath" />
    <xsl:param name="outputType" select="design"/>   <!-- Allows caller to use design or mixin for the class definitions -->

    <xsl:variable name="IBOrderedObjectRecords" select="/archive/data/object[@key='IBDocument.Objects']/object[@key='objectRecords']/object[@key='orderedObjects']"/>
    <xsl:variable name="IBFlattenedPropertyKeys" select="/archive/data/object[@key='IBDocument.Objects']/object[@key='flattenedProperties']/object[@key='dict.sortedKeys']"/>
    <xsl:variable name="IBFlattenedPropertyValues" select="/archive/data/object[@key='IBDocument.Objects']/object[@key='flattenedProperties']/object[@key='dict.values']"/>

    <xsl:variable name="CustomResources" select="/archive/data/object/descendant::object[@class='NSCustomResource']"/>

    <xsl:template name="lookupImageResource">
        <xsl:param name="node"/>
        <xsl:param name="key"/>
        <xsl:choose>
            <xsl:when test="$node/object[@key=$key]">
                <xsl:value-of select="$node/object[@key=$key]/string[@key='NSResourceName']"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="resourceRef" select="$node/reference[@key=$key]/@ref"/>
                <xsl:for-each select="$CustomResources">
                    <xsl:if test="@id = $resourceRef">
                        <xsl:value-of select="./string[@key='NSResourceName']"/>
                    </xsl:if>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- yes, one giant stylesheet because some(most, all?) browsers don't implement xsl:import/include -->
    <!-- NOTE - all flag constants/bit fields assume that the XIB file was created by XCode 3 or 4.  -->

    <!-- Top-level template that matches the whole document.  Creates an SC.Page with all root-level windows and views embedded in the document -->
    <xsl:template match="data">
        <xsl:value-of select="$namespace"/>.<xsl:value-of select="$pageName"/> = SC.Page.design({

        <xsl:variable name="IBstandins" select="object[@key='IBDocument.Objects']/object[@key='objectRecords']/object[@key='orderedObjects']"/>
        <xsl:for-each select="object[@key='IBDocument.RootObjects']/object">
            <xsl:choose>
                <!-- Available for backward compatibility, but unfortunately IB (rightly for desktop use) doesn't give a mechanism to allow the
                    window to consume all of a parent view's area.  For Sproutcore, recommend creating a custom view with name of SCMainPane
                    (which maps to SC.MainPane) -->
                <xsl:when test="string[@key='NSWindowClass'] = 'NSWindow'">
                    <xsl:call-template name="Window">
                        <xsl:with-param name="windowNode" select="."/>
                        <xsl:with-param name="windowName">
                            <xsl:call-template name="DetermineName">
                                <xsl:with-param name="nodeID" select='@id'/>
                            </xsl:call-template>
                        </xsl:with-param>
                     </xsl:call-template>
                </xsl:when>
                <!-- Available for backward compatibility, but unfortunately IB (rightly for desktop use) doesn't give a mechanism to allow the
                    panel to consume all of a parent view's area.  For Sproutcore, recommend creating a custom view with name of SCPanelPane
                    (which maps to SC.PanelPane) -->
                <xsl:when test="string[@key='NSWindowClass'] = 'NSPanel'">
                    <xsl:call-template name="Panel">
                        <xsl:with-param name="panelNode" select="."/>
                        <xsl:with-param name="panelName">
                            <xsl:call-template name="DetermineName">
                                <xsl:with-param name="nodeID" select='@id'/>
                            </xsl:call-template>
                        </xsl:with-param>
                     </xsl:call-template>
                </xsl:when>
                <!-- Any custom view should have a valid frame size - process -->
                <xsl:when test="string[@key='NSFrameSize'] != ''">
                    <!-- Choose template to call.  For PanelPane, we want to go to NSPanel template -->
                    <xsl:variable name="customClassName">
                        <xsl:call-template name="LookupClassName">
                            <xsl:with-param name="node" select="."/>
                            <xsl:with-param name="defaultClassName" select="'ClassNotKnown'"/>
                        </xsl:call-template>
                    </xsl:variable>
// Custom class ***<xsl:value-of select="normalize-space($customClassName)" />***

                    <xsl:choose>
                        <xsl:when test="normalize-space($customClassName) = 'SC.PanelPane'">
                            <xsl:call-template name="SC.PanelPane">
                                <xsl:with-param name="panelNode" select="."/>
                                <xsl:with-param name="panelName">
                                    <xsl:call-template name="DetermineName">
                                        <xsl:with-param name="nodeID" select='@id'/>
                                    </xsl:call-template>
                                </xsl:with-param>
                            </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:call-template name="FromCustomView">
                                <xsl:with-param name="windowNode" select="."/>
                                <xsl:with-param name="viewName">
                                    <xsl:call-template name="DetermineName">
                                        <xsl:with-param name="nodeID" select='@id'/>
                                    </xsl:call-template>
                                </xsl:with-param>
                             </xsl:call-template>
                         </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="./attribute::class = 'NSMenu'">
                    <xsl:call-template name="TopLevelNSMenu">
                        <xsl:with-param name="menuNode" select="."/>
                        <xsl:with-param name="menuName">
                            <xsl:call-template name="DetermineName">
                                <xsl:with-param name="nodeID" select='@id'/>
                            </xsl:call-template>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    /* Skipping unknown object.. */

                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
})
    </xsl:template>

    <!-- Template to look up IB's label for the defined view.  Useful to assign the view to a specific key in the parent
         view's class definition -->
    <xsl:template name="DetermineName">
        <xsl:param name="nodeID" />
        <xsl:for-each select="$IBOrderedObjectRecords/object">
            <xsl:if test="reference[@key='object']/attribute::ref = $nodeID">
                <xsl:value-of select="string[@key='objectName']"/>
            </xsl:if>
        </xsl:for-each>
    </xsl:template> 


    <!-- Utility template which looks up a custom class name in IB.  -->
    <xsl:template name="LookupClassName">
        <xsl:param name="node" />
        <xsl:param name="defaultClassName" />
        <!-- Two ways a custom class name could be defined - either as an element of key NSClassName in the object,
            or a record in the IB flattened property keys dictionary -->
        <xsl:variable name="CustomClassName">
            <xsl:choose>
                <xsl:when test="$node/string[@key='NSClassName']">
                    <xsl:value-of select="$node/string[@key='NSClassName']"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:variable name="IBPropertyID">
                        <xsl:for-each select="$IBOrderedObjectRecords/object[@class='IBObjectRecord']">
                            <xsl:if test="reference[@key='object']/@ref = $node/@id">
                                <xsl:value-of select="concat(int[@key='objectID'], '.CustomClassName')"/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:for-each select="$IBFlattenedPropertyKeys/*">
                        <xsl:if test=". = $IBPropertyID">
                            <xsl:variable name="arrayIndex" select="position()"/>
                            <xsl:value-of select="$IBFlattenedPropertyValues/*[$arrayIndex]"/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!--// LookupClassName: NSClassName entity = **<xsl:value-of select="$node/string[@key='NSClassName']"/>**
            //    CustomClassName variable = **<xsl:value-of select="$CustomClassName"/>**
            // -->
        <xsl:choose>
            <xsl:when test="starts-with($CustomClassName, 'SC')">
                SC.<xsl:value-of select="substring($CustomClassName,3)"/>
            </xsl:when>
            <xsl:when test="starts-with($CustomClassName, 'NS')">
                <xsl:value-of select="$defaultClassName"/>
            </xsl:when>
            <xsl:when test="string-length($CustomClassName)>0">
                <xsl:value-of select="concat($namespace, '.', $CustomClassName)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$defaultClassName"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Utility template for class front matter, including class name, mixins (as defined in
        the mixin key/value pair, and open brace -->
    <xsl:template name="EmitClassDeclarationFront">
        <xsl:param name="node" />
        <xsl:param name="defaultClassName" />
        <xsl:param name="propertyType" select="$outputType"/>

        <xsl:call-template name="LookupClassName">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="defaultClassName" select="$defaultClassName"/>
        </xsl:call-template>
        .<xsl:value-of select="$propertyType"/>(
        <xsl:variable name="mixinType">
            <xsl:call-template name="kvValueForKey">
                <xsl:with-param name="key" select="'mixin'"/>
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="string-length($mixinType) > 0">
            <xsl:value-of select="$mixinType"/>,
        </xsl:if>
        {
    </xsl:template>

    <!-- Utility template for class back matter.  Right now more for just balancing out the
        EmitClassDeclarationFront template, but we could add instrumentation at the end if
        we need to in the future -->
    <xsl:template name="EmitClassDeclarationBack">
        }),
    </xsl:template>

    <!-- Template to insert children of a given view.  Has special handling for named children - assigns the
        child in a member variable of the parent, and adds the member name to the child view list -->
    <xsl:template name="PopulateNamedChildren">
        <xsl:param name="children"/>
        <!-- First pass: generate child list.  May contain names for named children, otherwise, inline views -->
        childViews:[
            <xsl:for-each select="$children">
                <xsl:variable name="ChildName">
                    <xsl:call-template name="DetermineName">
                        <xsl:with-param name="nodeID" select="@id"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="$ChildName!=''">
                        "<xsl:value-of select="$ChildName"/>",
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="ProcessSingleNode">
                            <xsl:with-param name="node" select="."/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        ],

    <!-- Second pass: generate Key/Value pairs for each named child -->
        <xsl:for-each select="$children">
            <xsl:variable name="ChildName">
                <xsl:call-template name="DetermineName">
                    <xsl:with-param name="nodeID" select="@id"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:if test="$ChildName!=''">
                "<xsl:value-of select="$ChildName"/>" :
                <xsl:call-template name="ProcessSingleNode">
                    <xsl:with-param name="node" select="."/>
                </xsl:call-template>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <!-- Main switch block for inserting the definition of a single view.  Calls other templates as
         necessary -->
    <xsl:template name="ProcessSingleNode">
        <xsl:param name="node"/>
        <xsl:param name="overrideLayout" select="false()"/>
        <xsl:choose>
            <xsl:when test="$node[@class='NSTextField']">
                <xsl:call-template name="NSTextField">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSSplitView']">
                <xsl:call-template name="NSSplitView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='IKImageView']">
                <xsl:call-template name="IKImageView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSImageView']">
                <xsl:call-template name="NSImageView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSButton']">
                <xsl:call-template name="NSButton">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSSlider']">
                <xsl:call-template name="NSSlider">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSProgressIndicator']">
                <xsl:call-template name="NSProgressIndicator">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>                
            <xsl:when test="$node[@class='NSCollectionView']">
                <xsl:call-template name="NSCollectionView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSOutlineView']">
                <xsl:call-template name="NSOutlineView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSTableView']">
                <xsl:call-template name="NSTableView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSScrollView']">
                <xsl:call-template name="NSScrollView">
                    <xsl:with-param name="node" select="$node"/>
                    <xsl:with-param name="overrideLayout" select="$overrideLayout"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSPopUpButton']">
                <xsl:call-template name="NSPopUpButton">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSSegmentedControl']">
                <xsl:call-template name="NSSegmentedControl">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='WebView']">
                <xsl:call-template name="WebView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSMatrix']">
                <xsl:call-template name="NSMatrix">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSTabView']">
                <xsl:call-template name="NSTabView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSBox']">
                <xsl:call-template name="NSBox">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node[@class='NSClipView']">
                <xsl:call-template name="NSClipView">
                    <xsl:with-param name="node" select="$node"/>
                </xsl:call-template>
            </xsl:when>

            <xsl:otherwise>
                <xsl:call-template name="NSCustomView">
                    <xsl:with-param name="node" select="$node"/>
                    <xsl:with-param name="overrideLayout" select="$overrideLayout"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- class properties -->
    <xsl:template name="KeyValuePropertiesForObject">
        <xsl:param name="objectId" />
        <xsl:for-each select="$IBFlattenedPropertyValues/object/object[@class='IBUserDefinedRuntimeAttributesPlaceholder']">
            <xsl:if test="./reference/@ref = $objectId">
                <xsl:for-each select="./*[@key='userDefinedRuntimeAttributes']/*[@class='IBUserDefinedRuntimeAttribute']">
                    <xsl:if test="./string[@key='keyPath']!='mixin'">
                        <xsl:value-of select="./string[@key='keyPath']" />:
                        <xsl:choose>
                            <xsl:when test="./real/@value">
                                <xsl:value-of select="./real/@value" />
                            </xsl:when>
                            <xsl:when test="./boolean/@value">
                                <xsl:value-of select="./boolean/@value" />
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='exampleView'">
                                <xsl:value-of select="./string[@key='value']" />
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='recordType'">
                                <xsl:value-of select="./string[@key='value']" />
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='fontWeight'">
                                <xsl:value-of select="./string[@key='value']" />
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='displayProperties'">
                                "<xsl:value-of select="./string[@key='value']" />".w()
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='classNames'">
                                "<xsl:value-of select="./string[@key='value']" />".w()
                            </xsl:when>
                            <xsl:when test="./string[@key='keyPath']='hint'">
                                "<xsl:value-of select="hexConvert:escapeSpecialCharacters(./string[@key='value'])" />".loc()
                            </xsl:when>
                            <xsl:when test="contains(./string[@key='keyPath'], 'Binding') and contains(./string[@key='value'], 'SC.Binding')" >
                                <xsl:choose>
                                    <xsl:when test="string-length(./string[@key='value']) > 0">
                                        <xsl:value-of select="./string[@key='value']" />
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <!--  Sproutcore blows up if the binding value is an empty string... Add a string with a parse error to halt SCXIB proc -->
                                        BINDING NOT SET PLEASE FIX
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:when>
                            <xsl:when test="contains(./string[@key='keyPath'], 'Binding')">
                                <xsl:choose>
                                    <xsl:when test="string-length(./string[@key='value']) > 0">
                                        "<xsl:value-of select="./string[@key='value']" />"
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <!--  Sproutcore blows up if the binding value is an empty string... Add a string with a parse error to halt SCXIB proc -->
                                        ***BINDING NOT SET PLEASE FIX***
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:when>
                            <xsl:otherwise>
                                "<xsl:value-of select="hexConvert:escapeSpecialCharacters(./string[@key='value'])" />"
                            </xsl:otherwise>
                        </xsl:choose>,
                    </xsl:if>
                </xsl:for-each>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="kvValueForKey">
        <xsl:param name="objectId" />
        <xsl:param name="key" />
        <xsl:for-each select="//object[@key='IBDocument.Objects']/object[@key='flattenedProperties']/object[@key='dict.values']/object/object       [@class='IBUserDefinedRuntimeAttributesPlaceholder']">
            <xsl:if test="./reference/@ref = $objectId">
                <xsl:for-each select="./*[@key='userDefinedRuntimeAttributes']/*[@class='IBUserDefinedRuntimeAttribute']">
                    <xsl:if test="./string[@key='keyPath'] = $key">
                        <xsl:choose>
                            <xsl:when test="./real/@value">
                                <xsl:value-of select="./real/@value" />
                            </xsl:when>
                            <xsl:when test="./boolean/@value">
                                <xsl:value-of select="./boolean/@value" />
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="./string[@key='value']" />
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </xsl:for-each>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="DimensionsFromString">
        <xsl:param name="layoutString"/>        
        <xsl:variable name="d1">
            <xsl:call-template name="str:replace">
                <xsl:with-param name="search" select="'{'" />
                <xsl:with-param name="string" select="$layoutString" />
                <xsl:with-param name="replace" select="''" />
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="d2">
            <xsl:call-template name="str:replace">
                <xsl:with-param name="search" select="'}'" />
                <xsl:with-param name="string" select="$d1" />
                <xsl:with-param name="replace" select="''" />
            </xsl:call-template>
        </xsl:variable>
            <xsl:call-template name="str:split">
               <xsl:with-param name="string" select="$d2" />
               <xsl:with-param name="pattern" select="','" />
            </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="LayoutFromRect">
        <xsl:param name="layoutString"/>
        <xsl:param name="NSWTFlags"/>
        <xsl:variable name="IBWindowPositionMask">
            <xsl:value-of select='hexConvert:extractField($NSWTFlags, 19,5)'/>
        </xsl:variable>
        <xsl:variable name="dimensions">
            <xsl:call-template name="DimensionsFromString">
                 <xsl:with-param name="layoutString" select="$layoutString"/>
             </xsl:call-template>
        </xsl:variable>
        <xsl:if test="count(exsl:node-set($dimensions)/token) &gt; 0">
            layout: {
            <xsl:choose>
                <xsl:when test="$IBWindowPositionMask = '15'">
                    centerX: 0,
                    centerY: 0,
                </xsl:when>
                <xsl:otherwise>
                    bottom: <xsl:value-of select="exsl:node-set($dimensions)/token[2]"/>,
                    left: <xsl:value-of select="exsl:node-set($dimensions)/token[1]"/>,
                </xsl:otherwise>
            </xsl:choose>
            width: <xsl:value-of select="exsl:node-set($dimensions)/token[3]"/>,
            height: <xsl:value-of select="exsl:node-set($dimensions)/token[4]"/>
            },
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="LayoutFromFrame">
        <xsl:param name="parentNodeRefId"/>
        <xsl:param name="node"/>

        <xsl:variable name="layoutString">
            <xsl:choose>
                <xsl:when test="$node/string[@key='NSFrame']">
                   <xsl:value-of select="$node/string[@key='NSFrame']"/>
                </xsl:when>
                <xsl:otherwise>
                    { {0,0}, <xsl:value-of select="$node/string[@key='NSFrameSize']"/> }
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="parentNode">
            <xsl:call-template name="NodeFromRef">
                 <xsl:with-param name="nodes" select="//*"/>
                 <xsl:with-param name="refId" select="$parentNodeRefId"/>
             </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="dimensions">
            <xsl:call-template name="DimensionsFromString">
                 <xsl:with-param name="layoutString" select="$layoutString"/>
             </xsl:call-template>
        </xsl:variable>

        <xsl:variable name="fr">
            <xsl:choose>
                <xsl:when test="exsl:node-set($parentNode)[1]/*/string[@key='NSFrame']">
                    <xsl:value-of select="exsl:node-set($parentNode)[1]/*/string[@key='NSFrame']"/>
                </xsl:when>
                <xsl:when test="exsl:node-set($parentNode)[1]/*/string[@key='NSFrameSize']">
                    <xsl:value-of select="exsl:node-set($parentNode)[1]/*/string[@key='NSFrameSize']"/>
                </xsl:when>
                <xsl:otherwise>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>        
        <xsl:variable name="parentDimensions">
            <xsl:call-template name="DimensionsFromString">
                 <xsl:with-param name="layoutString" select="$fr"/>
             </xsl:call-template>
        </xsl:variable>
                
         <xsl:variable name="top">
             <xsl:choose>
                 <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 2">
                     <xsl:value-of select="number(exsl:node-set($parentDimensions)/token[2]) - (number(exsl:node-set($dimensions)/token[4]) + number(exsl:node-set($dimensions)/token[2]))"/>
                </xsl:when>
                <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 4">
                    <xsl:value-of select="number(exsl:node-set($parentDimensions)/token[4]) - (number(exsl:node-set($dimensions)/token[4]) + number(exsl:node-set($dimensions)/token[2]))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="0"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
         <xsl:variable name="parentHeight">
             <xsl:choose>
                 <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 2">
                     <xsl:value-of select="number(normalize-space(exsl:node-set($parentDimensions)/token[2]))"/>
                </xsl:when>
                <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 4">
                    <xsl:value-of select="number(normalize-space(exsl:node-set($parentDimensions)/token[4]))"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- If the parent is nowhere to be found, assume it's same size as the current node -->
                    <xsl:value-of select="exsl:node-set($dimensions)/token[4]"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="parentWidth">
            <xsl:choose>
                <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 2">
                    <xsl:value-of select="number(normalize-space(exsl:node-set($parentDimensions)/token[1]))"/>
                </xsl:when>
                <xsl:when test="count(exsl:node-set($parentDimensions)/token) = 4">
                    <xsl:value-of select="number(normalize-space(exsl:node-set($parentDimensions)/token[3]))"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- If the parent is nowhere to be found, assume it's same size as the current node -->
                    <xsl:value-of select="exsl:node-set($dimensions)/token[3]"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="leftStrutSet" select="not (floor($node/*[@key='NSvFlags']) mod 2 = 1)"/>
        <xsl:variable name="variableWidth" select="(floor($node/*[@key='NSvFlags'] div 2) mod 2 = 1)"/>
        <xsl:variable name="rightStrutSet" select="not (floor($node/*[@key='NSvFlags'] div 4) mod 2 = 1)"/>
        <xsl:variable name="bottomStrutSet" select="not (floor($node/*[@key='NSvFlags'] div 8) mod 2 = 1)"/>
        <xsl:variable name="variableHeight" select="(floor($node/*[@key='NSvFlags'] div 16) mod 2 = 1)"/>
        <xsl:variable name="topStrutSet" select="not (floor($node/*[@key='NSvFlags'] div 32) mod 2 = 1)"/>
        <xsl:if test="count(exsl:node-set($dimensions)/token) &gt; 0">
            layout: {
            <xsl:variable name="frame">
                <frame>                                        
                    <xsl:choose>
                        <xsl:when test="count(exsl:node-set($dimensions)/token) = 2">
                            <top>
                                <xsl:value-of select="$top"/>
                            </top>
                            <width>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[1]"/>
                            </width>
                            <height>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[2]"/>
                            </height>
                        </xsl:when>
                        <xsl:when test="count(exsl:node-set($dimensions)/token) = 4">
                            <top>
                                <xsl:value-of select="$top"/>
                            </top>
                            <left>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[1]"/>
                            </left>
                            <bottom>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[2]"/>
                            </bottom>
                            <width>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[3]"/>
                            </width>
                            <height>
                                <xsl:value-of select="exsl:node-set($dimensions)/token[4]"/>
                            </height>
                        </xsl:when>
                        <xsl:otherwise>
                             <top>0</top><left>0</left>
                        </xsl:otherwise>
                    </xsl:choose>
                </frame>
            </xsl:variable>
<!-- Debugging output -->
<!--// Right strut set = <xsl:value-of select="$rightStrutSet"/>
// Variable width = <xsl:value-of select="$variableWidth"/>
// Left strut set = <xsl:value-of select="$leftStrutSet"/>
// Bottom strut set = <xsl:value-of select="$bottomStrutSet"/>
// Variable height = <xsl:value-of select="$variableHeight"/>
// Top strut set = <xsl:value-of select="$topStrutSet"/>
// Layout String: <xsl:value-of select="$layoutString"/>
// Frame: top=<xsl:value-of select="exsl:node-set($frame)/frame/top"/> bottom=<xsl:value-of select="exsl:node-set($frame)/frame/bottom"/> width=<xsl:value-of select="exsl:node-set($frame)/frame/width"/> height=<xsl:value-of select="exsl:node-set($frame)/frame/height"/>
// ParentWidth = <xsl:value-of select="$parentWidth"/>
// ParentHeight = <xsl:value-of select="$parentHeight"/> -->
<!-- End of debugging output -->
            <xsl:choose>
                <xsl:when test="$variableWidth">
                    <!-- Typically, the left and right sides should be pinned to allow the view to grow and shrink -->
                        left: <xsl:value-of select="exsl:node-set($frame)/frame/left"/>,
                        right: <xsl:value-of select="$parentWidth - exsl:node-set($frame)/frame/width - exsl:node-set($frame)/frame/left"/>,
                </xsl:when>
                <xsl:otherwise>
                    <!-- Typically, if width is fixed, one or the other side is pinned, but not both -->
                    <xsl:choose>
                        <xsl:when test="$rightStrutSet">
                            right: <xsl:value-of select="$parentWidth - exsl:node-set($frame)/frame/width - exsl:node-set($frame)/frame/left"/>,
                        </xsl:when>
                        <xsl:when test="$leftStrutSet">
                            left: <xsl:value-of select="exsl:node-set($frame)/frame/left"/>,
                        </xsl:when>
                        <xsl:otherwise> 
                            <!-- Neither strut set.  Assume centering from center of child's frame, in parent's coordinate system -->
                            centerX: <xsl:value-of select="floor(exsl:node-set($frame)/frame/left + (exsl:node-set($frame)/frame/width div 2) - ($parentWidth div 2))"/>,
                        </xsl:otherwise>
                    </xsl:choose>
                    width: <xsl:value-of select="exsl:node-set($frame)/frame/width"/>,
                </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="$variableHeight">
                    <!-- Typically, the top and bottom sides should be pinned to allow the view to grow and shrink -->
                    top: <xsl:value-of select="exsl:node-set($frame)/frame/top"/>,
                    bottom: <xsl:value-of select="exsl:node-set($frame)/frame/bottom"/>,
                </xsl:when>
                <xsl:otherwise>
                    <!-- Typically, if height is fixed, top or bottom side is pinned, but not both -->
                    <xsl:choose>
                        <xsl:when test="$bottomStrutSet">
                            bottom:  <xsl:value-of select="exsl:node-set($frame)/frame/bottom"/>,
                        </xsl:when>
                        <xsl:when test="$topStrutSet">
                            top:  <xsl:value-of select="exsl:node-set($frame)/frame/top"/>,
                        </xsl:when>
                        <xsl:otherwise> 
                            <!-- Neither strut set.  Assume centering from center of child's frame, in parent's coordinate system -->
                            centerY: <xsl:value-of select="floor(exsl:node-set($frame)/frame/top + (exsl:node-set($frame)/frame/height div 2) - ($parentHeight div 2))"/>,
                        </xsl:otherwise>
                    </xsl:choose>
                    height:  <xsl:value-of select="exsl:node-set($frame)/frame/height"/>,
                </xsl:otherwise>
            </xsl:choose>
            },
        </xsl:if>
    </xsl:template>

    <xsl:template name="ProcessTabs">
        <xsl:param name="nodes" />
        <xsl:for-each select="$nodes">
            <xsl:choose>
                <xsl:when test="./@class='NSTabView'">
                    <xsl:for-each select="./*[@key='NSTabViewItems']/*[@class='NSTabViewItem']">
                            <xsl:value-of select="concat(
                                    $namespace,
                                    '._',
                                    ./@id)"/> = 

                                    SC.Page.create({

                                      mainView:
                                        <xsl:call-template name="NSCustomView">
                                            <xsl:with-param name="node" select="./*[@class='NSView']" />
                                        </xsl:call-template>
                                    });
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="ProcessTabs">
                        <xsl:with-param name="nodes" select="./*[@key='NSSubviews']/*" />
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="NodeFromRef">
        <xsl:param name="nodes" />
        <xsl:param name="refId" />
        <xsl:for-each select="$nodes">
            <xsl:choose>
                <xsl:when test="./@id=$refId">
                    <xsl:copy-of select="."/>
                </xsl:when>
                <xsl:otherwise>
                     <xsl:call-template name="NodeFromRef">
                         <xsl:with-param name="nodes" select="./*[@key='NSSubviews']/object" />
                         <xsl:with-param name="refId" select="$refId" />
                     </xsl:call-template>
                 </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>

    <!-- NS to SC class mappings -->

    <xsl:template name="Window">
        <xsl:param name="windowNode"/>
        <xsl:param name="windowName"/>

        <xsl:call-template name="ProcessTabs">
            <xsl:with-param name="nodes" select="$windowNode/object[@key='NSWindowView']/*[@key='NSSubviews']/object" />
        </xsl:call-template>
        <xsl:value-of select="$windowName"/> : SC.MainPane.<xsl:value-of select="$outputType"/>({
            <xsl:call-template name="LayoutFromRect">
                <xsl:with-param name="layoutString" select="$windowNode/string[@key='NSWindowRect']"/>
                <xsl:with-param name="NSWTFlags" select="$windowNode/int[@key='NSWTFlags']"/>
            </xsl:call-template>
            <xsl:call-template name="PopulateNamedChildren">
                <xsl:with-param name="children" select="$windowNode/object[@key='NSWindowView']/*[@key='NSSubviews']/object"/>
            </xsl:call-template>
        }),
    </xsl:template>
    
    <xsl:template name="FromCustomView">
        <xsl:param name="windowNode"/>
        <xsl:param name="viewName"/>

        <xsl:call-template name="ProcessTabs">
            <xsl:with-param name="nodes" select="$windowNode/*[@key='NSSubviews']/object" />
        </xsl:call-template>
        <xsl:value-of select="$viewName"/> : 
        <xsl:call-template name="NSCustomView">
            <xsl:with-param name="node" select="$windowNode"/>
            <xsl:with-param name="propertyType" select="$outputType"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Instead of using NSPanel template, allow creating an SC.PanelPane from a standard custom view, to allow
        full power of struts and springs (Sproutcore PanelPanes are more like views than windows -->
    <xsl:template name="SC.PanelPane">
        <xsl:param name="panelNode"/>
        <xsl:param name="panelName"/>
        <xsl:call-template name="ProcessTabs">
            <xsl:with-param name="nodes" select="$panelNode/object[@key='NSWindowView']/*[@key='NSSubviews']/object" />
        </xsl:call-template>

        <xsl:value-of select="$panelName"/> :

        <xsl:call-template name="EmitClassDeclarationFront">
            <xsl:with-param name="node" select="$panelNode"/>
            <xsl:with-param name="defaultClassName" select="'SC.PanelPane'"/>
        </xsl:call-template>

        <xsl:call-template name="LayoutFromFrame">
            <xsl:with-param name="node" select="$panelNode"/>
            <xsl:with-param name="parentNodeRefId" select="$panelNode/reference[@key='NSSuperview']/@ref"/>
        </xsl:call-template>

        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$panelNode/@id"/>
        </xsl:call-template>

        contentView: SC.View.design({
        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$panelNode/object[@key='NSWindowView']/@id"/>
        </xsl:call-template>

        <xsl:call-template name="PopulateNamedChildren">
            <xsl:with-param name="children" select="$panelNode/*[@key='NSSubviews']/object"/>
        </xsl:call-template>
        })
        <xsl:call-template name="EmitClassDeclarationBack"/>
    </xsl:template>

    <xsl:template name="Panel">
        <xsl:param name="panelNode"/>
        <xsl:param name="panelName"/>
        <xsl:call-template name="ProcessTabs">
            <xsl:with-param name="nodes" select="$panelNode/object[@key='NSWindowView']/*[@key='NSSubviews']/object" />
        </xsl:call-template>

        <xsl:value-of select="$panelName"/> :

        <xsl:call-template name="EmitClassDeclarationFront">
            <xsl:with-param name="node" select="$panelNode"/>
            <xsl:with-param name="defaultClassName" select="'SC.PanelPane'"/>
        </xsl:call-template>

        <xsl:call-template name="LayoutFromRect">
            <xsl:with-param name="layoutString" select="$panelNode/string[@key='NSWindowRect']"/>
            <xsl:with-param name="NSWTFlags" select="$panelNode/int[@key='NSWTFlags']"/>
        </xsl:call-template>

        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$panelNode/@id"/>
        </xsl:call-template>

        contentView: SC.View.design({
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$panelNode/object[@key='NSWindowView']/@id"/>
            </xsl:call-template>
            <xsl:call-template name="PopulateNamedChildren">
                <xsl:with-param name="children" select="$panelNode/object[@key='NSWindowView']/*[@key='NSSubviews']/object"/>
            </xsl:call-template>
        })
        <xsl:call-template name="EmitClassDeclarationBack"/>
    </xsl:template>

    <xsl:template name="NSCustomView">
        <xsl:param name="node" />
        <xsl:param name="propertyType" select="'design'"/>
        <xsl:param name="overrideLayout" select="false()"/>

        <xsl:call-template name="EmitClassDeclarationFront">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="defaultClassName" select="'SC.View'"/>
            <xsl:with-param name="propertyType" select="$propertyType"/>
        </xsl:call-template>

        <xsl:choose>
            <xsl:when test="$overrideLayout">
                layout: {top:0, bottom: 0, left: 0, right: 0},
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="LayoutFromFrame">
                    <xsl:with-param name="node" select="$node"/>
                    <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$node/@id"/>
        </xsl:call-template>
        <xsl:if test="count($node/*[@key='NSSubviews']/object) &gt; 0">
            <xsl:call-template name="PopulateNamedChildren">
                <xsl:with-param name="children" select="$node/*[@key='NSSubviews']/object"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:call-template name="EmitClassDeclarationBack"/>
    </xsl:template>

    <xsl:template name="NSTextField">
        <xsl:param name="node" />
            <xsl:choose>
                <xsl:when test="$node/object[@class='NSTextFieldCell']/int[@key='NSCellFlags'] = 68288064">
                    SC.LabelView.design({
                </xsl:when>
                <xsl:when test="$node/object[@class='NSTextFieldCell']/int[@key='NSCellFlags'] = 67239424">
                    SC.LabelView.design({
                </xsl:when>
                <xsl:otherwise>
                    SC.TextFieldView.design({
                    <xsl:if test="$node/object[@class='NSTextFieldCell']/string[@key='NSPlaceholderString']">
                        hint: "<xsl:value-of select="$node/object[@class='NSTextFieldCell']/string[@key='NSPlaceholderString']"/>".loc(),
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="$node/object[@class='NSTextFieldCell']/int[@key='NSCellFlags'] = -1805517311">
               isTextArea: YES,
            </xsl:if>
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="ValueBinding">
                <xsl:call-template name="kvValueForKey">
                    <xsl:with-param name="key" select="'valueBinding'"/>
                    <xsl:with-param name="objectId" select="$node/@id"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:if test="$ValueBinding=''">
                <xsl:choose>
                    <xsl:when test="$node/object[@class='NSTextFieldCell']/string[@key='NSContents']/@type = 'base64-UTF8'">
                        value: "<xsl:value-of select="hexConvert:base64DecodeEscaped($node/object[@class='NSTextFieldCell']/string[@key='NSContents'])" />".loc()
                    </xsl:when>
                    <xsl:otherwise>
                        value: "<xsl:value-of select="hexConvert:escapeSpecialCharacters($node/object[@class='NSTextFieldCell']/string[@key='NSContents'])" />".loc()
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        }),
    </xsl:template>

    <xsl:template name="NSSplitView">
        <xsl:param name="node" />
        SC.SplitView.design({
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            layoutDirection:
                <xsl:choose>
                    <xsl:when test="$node/bool[@key='NSIsVertical'] = YES">
                        SC.LAYOUT_VERTICAL
                    </xsl:when>
                    <xsl:otherwise>
                        SC.LAYOUT_HORIZONTAL
                    </xsl:otherwise>
                </xsl:choose>,
            dividerThickness:
                <xsl:choose>
                    <xsl:when test="$node/int[@key='NSDividerStyle'] = 3">
                        1
                    </xsl:when>
                    <xsl:otherwise>
                        5
                    </xsl:otherwise>
                </xsl:choose>,
            topLeftView:
                <xsl:call-template name="ProcessSingleNode">
                    <xsl:with-param name="node" select="$node/*[@key='NSSubviews']/object[1]"/>
                    <xsl:with-param name="overrideLayout" select="true()"/>
                </xsl:call-template>
            dividerView: SC.SplitDividerView,
            bottomRightView:
                <xsl:call-template name="ProcessSingleNode">
                    <xsl:with-param name="node" select="$node/*[@key='NSSubviews']/object[2]"/>
                    <xsl:with-param name="overrideLayout" select="true()"/>
                </xsl:call-template>
        }),
    </xsl:template>

    <xsl:template name="IKImageView">
        <xsl:param name="node" />
        SC.ImageView.design({
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:variable name="uri">
                <xsl:call-template name="kvValueForKey">
                    <xsl:with-param name="key" select="'value'"/>
                    <xsl:with-param name="objectId" select="$node/@id"/>
                </xsl:call-template>
            </xsl:variable>
            value:"<xsl:value-of select="$resourcesPath"/>images/<xsl:value-of select="normalize-space($uri)"/>"
        }),
    </xsl:template>

    <xsl:template name="NSImageView">
        <xsl:param name="node" />
        <xsl:call-template name="LookupClassName">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="defaultClassName" select="'SC.ImageView'" />
        </xsl:call-template>
        .design({
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="uri">
                <xsl:call-template name="lookupImageResource">
                    <xsl:with-param name="node" select="$node/object[@key='NSCell']"/>
                    <xsl:with-param name="key" select="'NSContents'"/>
                </xsl:call-template>
            </xsl:variable>
            value:"<xsl:value-of select="$resourcesPath"/> <xsl:value-of select="normalize-space($uri)"/>"
        }),
    </xsl:template>

    <xsl:template name="NSButton">
        <xsl:param name="node" />

            <xsl:variable name="className">
                <xsl:choose>
                    <xsl:when test="$node/object[@class='NSButtonCell']/int[@key='NSButtonFlags2'] = 2">
                        SC.CheckboxView
                    </xsl:when>                
                    <xsl:otherwise>
                        <xsl:call-template name="LookupClassName">
                            <xsl:with-param name="node" select="$node"/>
                            <xsl:with-param name="defaultClassName" select="'SC.ButtonView'" />
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:value-of select="$className"/>.design({
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="uri">
                <xsl:call-template name="lookupImageResource">
                    <xsl:with-param name="node" select="$node/object[@key='NSCell']"/>
                    <xsl:with-param name="key" select="'NSNormalImage'"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="normalize-space($className) = 'SC.ImageButtonView'">
                    <xsl:if test="$uri">
                        image:"<xsl:value-of select="$resourcesPath"/> <xsl:value-of select="normalize-space($uri)"/>"
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="$node/object[@class='NSButtonCell']/string[@key='NSContents']/@type = 'base64-UTF8'">
                            title: "<xsl:value-of select="hexConvert:base64DecodeEscaped($node/object[@class='NSButtonCell']/string[@key='NSContents'])" />".loc()
                        </xsl:when>
                        <xsl:otherwise>
                            title: "<xsl:value-of select="hexConvert:escapeSpecialCharacters($node/object[@class='NSButtonCell']/string[@key='NSContents'])" />".loc()
                        </xsl:otherwise>
                    </xsl:choose>,
                    <xsl:if test="$uri">
                        icon:"<xsl:value-of select="$resourcesPath"/> <xsl:value-of select="normalize-space($uri)"/>"
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        }),
    </xsl:template>

    <xsl:template name="NSPopUpButton">
        <xsl:param name="node" />

        SC.SelectFieldView.design({        
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="nameKey">
                <xsl:call-template name="kvValueForKey">
                    <xsl:with-param name="key" select="'nameKey'"/>
                    <xsl:with-param name="objectId" select="$node/@id"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:if test="$nameKey=''">
                nameKey: "title",
                objects:
                <xsl:call-template name="PopulateMenuItems">
                    <xsl:with-param name="children" select="$node/descendant::object[@class='NSMenuItem']"/>
                </xsl:call-template>
            </xsl:if>
        }),
    </xsl:template>
    
    <xsl:template name="NSProgressIndicator">
        <xsl:param name="node" />

        SC.ProgressView.design({        
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            minimum: 0, 
            maximum: <xsl:value-of select="./double[@key='NSMaxValue']"/>,
            value: 50,
            isIndeterminate: YES
        }),
    </xsl:template>

    <xsl:template name="NSSegmentedControl">
        <xsl:param name="node" />

        SC.SegmentedView.design({        
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            items: [
                <xsl:for-each select="$node/object[@class='NSSegmentedCell']/object[@class='NSMutableArray']/object[@class='NSSegmentItem']">
                    "<xsl:value-of select="string[@key='NSSegmentItemLabel']" />",
                </xsl:for-each>
                ]
        }),
    </xsl:template>
    
    <xsl:template name="NSSlider">
           <xsl:param name="node" />

           SC.SliderView.design({        
               <xsl:call-template name="LayoutFromFrame">
                               <xsl:with-param name="node" select="$node"/>
                   <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
               </xsl:call-template>
               <xsl:call-template name="KeyValuePropertiesForObject">
                   <xsl:with-param name="objectId" select="$node/@id"/>
               </xsl:call-template>
               minimum:<xsl:value-of select="./object[@class='NSSliderCell']/double[@key='NSMinValue']"/>,
               maximum:<xsl:value-of select="./object[@class='NSSliderCell']/double[@key='NSMaxValue']"/>,
               value:<xsl:value-of select="./object[@class='NSSliderCell']/double[@key='NSValue']"/>,
               steps:<xsl:value-of select="./object[@class='NSSliderCell']/double[@key='NSAltIncValue']"/>,
           }),
    </xsl:template>

    <xsl:template name="NSOutlineView">
        <xsl:param name="node" />
        SC.SourceListView.design({
            <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:call-template name="exampleView">
                <xsl:with-param name="node" select="$node"/>
            </xsl:call-template>
        }),
    </xsl:template>
    
    <xsl:template name="NSCollectionView">
        <xsl:param name="node" />
        SC.ListView.design({
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:call-template name="exampleView">
                <xsl:with-param name="node" select="$node"/>
            </xsl:call-template>
        }),
    </xsl:template>
    
    <xsl:template name="exampleView">
        <xsl:param name="node"/>
        <xsl:for-each select="//object[@key='IBDocument.Objects']/*[@key='connectionRecords']/*/*[@class='IBOutletConnection']">
        <xsl:if test="./reference[@key='source']/@ref = $node/@id and ./string[@key='label'] = 'itemPrototype'">
            <xsl:variable name="destinationId" select="./reference[@key='destination']/@ref"/>
            <xsl:variable name="customClassId">
                <xsl:for-each select="//object[@key='IBDocument.Objects']/*[@key='objectRecords']/*/*[@class='IBObjectRecord']">
                    <xsl:if test="$destinationId = ./reference[@key='object']/@ref"><xsl:value-of select="./int[@key='objectID']"/>.CustomClassName</xsl:if>
                </xsl:for-each>
            </xsl:variable>
            <xsl:if test="$customClassId and //object[@key='IBDocument.Objects']/*[@key='flattenedProperties']/string[@key=$customClassId]">
                exampleView: <xsl:value-of select="$namespace"/>.<xsl:value-of select="//object[@key='IBDocument.Objects']/*[@key='flattenedProperties']/string[@key=$customClassId]"/>
            </xsl:if>
        </xsl:if>
       </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="NSScrollView">
        <xsl:param name="node" />
        <xsl:param name="overrideLayout" select="false()"/>
        SC.ScrollView.design({
            <xsl:choose>
                <xsl:when test="$overrideLayout">
                    layout: {top:0, bottom: 0, left: 0, right: 0},
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="LayoutFromFrame">
                        <xsl:with-param name="node" select="$node"/>
                        <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            contentView:
                <xsl:call-template name="ProcessSingleNode">
                    <xsl:with-param name="node" select="$node/*[@key='NSSubviews']/object[1]"/>
                </xsl:call-template>
        }),
    </xsl:template>

    <xsl:template name="WebView">
        <xsl:param name="node" />

        SC.WebView.design({        
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            value:
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
        }),
    </xsl:template>

    <xsl:template name="NSMatrix">
        <xsl:param name="node" />
        SC.RadioView.design({
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:variable name="titleBindingKey">
                <xsl:call-template name="kvValueForKey">
                    <xsl:with-param name="objectId" select="$node/@id"/>
                    <xsl:with-param name="key">itemTitleKey</xsl:with-param>
                </xsl:call-template>
            </xsl:variable>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template> 
            items: [
                <xsl:for-each select="$node/object[@class='NSMutableArray']/object[@class='NSButtonCell']">
                    <xsl:choose>
                        <xsl:when test="$titleBindingKey!=''">
                            {
                                <xsl:value-of select='$titleBindingKey'/> : "<xsl:value-of select="string[@key='NSContents']" />".loc(),
                                <xsl:call-template name="KeyValuePropertiesForObject">
                                    <xsl:with-param name="objectId" select="@id"/>
                                </xsl:call-template>
                            },
                        </xsl:when>
                        <xsl:otherwise>
                            "<xsl:value-of select="string[@key='NSContents']" />".loc(),
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                ]
        }),
    </xsl:template>

    <xsl:template name="NSTabView">
        <xsl:param name="node" />
        SC.TabView.design({
            itemTitleKey: "title",
            itemValueKey: "value",
            <xsl:call-template name="LayoutFromFrame">
                            <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template>
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="tabPages">
            <xsl:for-each select="$node/*[@key='NSTabViewItems']/*[@class='NSTabViewItem']">
                    <tabPage>
                        <label>
                            <xsl:value-of select="string[@key='NSLabel']" />
                        </label>
                        <pageName>
                            <xsl:value-of select="concat(
                                    $namespace,
                                    '._',
                                    ./@id)"/>
                        </pageName>
                        <xsl:copy-of select="./*[@class='NSView']"/>
                    </tabPage>
            </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="selectedTab">
                <xsl:value-of select="concat(
                        $namespace,
                        '._',
                        ./reference[@key='NSSelectedTabViewItem']/@ref)"/>
            </xsl:variable>            
            nowShowing: "<xsl:value-of select="$selectedTab"/>.mainView",
            items: [
                <xsl:for-each select="exsl:node-set($tabPages)/tabPage">
                    {
                        title: "<xsl:value-of select="./label"/>",
                        value: "<xsl:value-of select="./pageName"/>.mainView"
                    },
                </xsl:for-each>
                ],
        }),
    </xsl:template>
    
    <xsl:template name="NSTableView">
        <xsl:param name="node" />
        SC.TableView.design({
           <!-- <xsl:call-template name="LayoutFromFrame">
                <xsl:with-param name="node" select="$node"/>
                <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
            </xsl:call-template> -->
            layout: { left: 0, right: 0, top: 0, bottom: 0 },
            <xsl:call-template name="KeyValuePropertiesForObject">
                <xsl:with-param name="objectId" select="$node/@id"/>
            </xsl:call-template>
            <xsl:variable name="tableColumns">
            <xsl:for-each select="$node/*[@key='NSTableColumns']/*[@class='NSTableColumn']">
                    <tableColumn>
                        <label>
                            <xsl:value-of select="*[@class='NSTableHeaderCell']/string[@key='NSContents']" />
                        </label>
                        <width>
                            <xsl:value-of select="double[@key='NSWidth']" />
                        </width>
                        <nodeid>
                            <xsl:value-of select="./@id"/>
                        </nodeid>
                        <identifier>
                            <xsl:value-of select="./string[@key='NSIdentifier']" />
                        </identifier>
                    </tableColumn>
            </xsl:for-each>
            </xsl:variable>
            columns: [
                <xsl:for-each select="exsl:node-set($tableColumns)/tableColumn">
                    SC.TableColumn.create({
                        title: "<xsl:value-of select="./label"/>",
                        key: "<xsl:value-of select="./identifier"/>",
                        width: <xsl:value-of select="./width"/>,
                        <xsl:call-template name="KeyValuePropertiesForObject">
                            <xsl:with-param name="objectId" select="./nodeid"/>
                        </xsl:call-template>
                    }),
                </xsl:for-each>
                ],
        }),
    </xsl:template>
    
    <xsl:template name="NSBox">
        <xsl:param name="node" />

        <xsl:choose>
            <xsl:when test="$node/int[@key='NSBoxType'] = 2">
                SC.SeparatorView.design({
                    layoutDirection: SC.LAYOUT_HORIZONTAL,
            </xsl:when>
            <xsl:when test="$node/int[@key='NSBoxType'] = 1">
                SC.SeparatorView.design({
                    layoutDirection: SC.LAYOUT_VERTICAL,
            </xsl:when>
            <xsl:when test="$node/int[@key='NSBoxType'] = 0">
                SC.ContainerView.design({
                    classNames: ["sc-view","sc-tab-view"],
                    contentView: SC.View.design({
                        classNames: ["sc-view", "sc-container-view", "sc-black-border"],
                        <xsl:call-template name="PopulateNamedChildren">
                            <xsl:with-param name="children" select="$node/*[@key='NSSubviews']/object"/>
                        </xsl:call-template>
                    }),
            </xsl:when>
        </xsl:choose>
        <xsl:call-template name="LayoutFromFrame">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="parentNodeRefId" select="$node/reference[@key='NSSuperview']/@ref"/>
        </xsl:call-template>
        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$node/@id"/>
        </xsl:call-template>
                }),
    </xsl:template>
    
    <xsl:template name="NSClipView">
        <xsl:param name="node" />
        <xsl:call-template name="ProcessSingleNode">
            <xsl:with-param name="node" select="$node/*[@key='NSSubviews']/object[1]"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template name="PopulateMenuItems">
        <xsl:param name="children"/>
        [
            <xsl:for-each select="$children">
            {
                title: "<xsl:value-of select="hexConvert:escapeSpecialCharacters(./string[@key='NSTitle'])" />",
                <xsl:call-template name="KeyValuePropertiesForObject">
                    <xsl:with-param name="objectId" select="./@id"/>
                </xsl:call-template>
            },
            </xsl:for-each>
        ],
    </xsl:template>

    <xsl:template name="TopLevelNSMenu">
        <xsl:param name="menuNode"/>
        <xsl:param name="menuName"/>
        
        <xsl:value-of select="$menuName"/> :

        <xsl:call-template name="EmitClassDeclarationFront">
            <xsl:with-param name="node" select="$menuNode"/>
            <xsl:with-param name="defaultClassName" select="'SC.MenuPane'"/>
        </xsl:call-template>

        <xsl:call-template name="KeyValuePropertiesForObject">
            <xsl:with-param name="objectId" select="$menuNode/@id"/>
        </xsl:call-template>

        layout: { width: 300 },
        <xsl:if test="count($menuNode/*[@key='NSMenuItems']/object) &gt; 0">
            items:
            <xsl:call-template name="PopulateMenuItems">
                <xsl:with-param name="children" select="$menuNode/*[@key='NSMenuItems']/object"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:call-template name="EmitClassDeclarationBack"/>
    </xsl:template>
        
    <!-- utils -->

    <xsl:template name="str:split">
        <xsl:param name="string" select="''" />
      <xsl:param name="pattern" select="' '" />
      <xsl:choose>
        <xsl:when test="not($string)" />
        <xsl:when test="not($pattern)">
          <xsl:call-template name="str:_split-characters">
            <xsl:with-param name="string" select="$string" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="str:_split-pattern">
            <xsl:with-param name="string" select="$string" />
            <xsl:with-param name="pattern" select="$pattern" />
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template name="str:_split-characters">
      <xsl:param name="string" />
      <xsl:if test="$string">
        <token><xsl:value-of select="substring($string, 1, 1)" /></token>
        <xsl:call-template name="str:_split-characters">
          <xsl:with-param name="string" select="substring($string, 2)" />
        </xsl:call-template>
      </xsl:if>
    </xsl:template>

    <xsl:template name="str:_split-pattern">
      <xsl:param name="string" />
      <xsl:param name="pattern" />
      <xsl:choose>
        <xsl:when test="contains($string, $pattern)">
          <xsl:if test="not(starts-with($string, $pattern))">
            <token><xsl:value-of select="substring-before($string, $pattern)" /></token>
          </xsl:if>
          <xsl:call-template name="str:_split-pattern">
            <xsl:with-param name="string" select="substring-after($string, $pattern)" />
            <xsl:with-param name="pattern" select="$pattern" />
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <token><xsl:value-of select="$string" /></token>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template name="str:replace">
        <xsl:param name="string" select="''" />
       <xsl:param name="search" select="/.." />
       <xsl:param name="replace" select="/.." />
       <xsl:choose>
          <xsl:when test="not($string)" />
          <xsl:when test="not($search)">
            <xsl:value-of select="$string" />
          </xsl:when>
          <xsl:when test="function-available('exsl:node-set')">
             <!-- this converts the search and replace arguments to node sets
                  if they are one of the other XPath types -->
             <xsl:variable name="search-nodes-rtf">
               <xsl:copy-of select="$search" />
             </xsl:variable>
             <xsl:variable name="replace-nodes-rtf">
               <xsl:copy-of select="$replace" />
             </xsl:variable>
             <xsl:variable name="replacements-rtf">
                 <xsl:choose>
                     <xsl:when test="count(exsl:node-set($search-nodes-rtf)) &gt; 1">
                         <xsl:for-each select="exsl:node-set($search-nodes-rtf)/node()">
                             <xsl:variable name="pos" select="position()"/>
                             <replace search="{.}">
                                 <xsl:copy-of select="exsl:node-set($replace-nodes-rtf)/node()[$pos]"/>
                             </replace>
                         </xsl:for-each>
                     </xsl:when>
                     <xsl:otherwise>
                         <replace search="{$search}">
                             <xsl:copy-of select="$replace-nodes-rtf"/>
                         </replace>
                     </xsl:otherwise>
                 </xsl:choose>
             </xsl:variable>
             <xsl:variable name="sorted-replacements-rtf">
                <xsl:for-each select="exsl:node-set($replacements-rtf)/replace">
                   <xsl:sort select="string-length(@search)" data-type="number" order="descending" />
                   <xsl:copy-of select="." />
                </xsl:for-each>
             </xsl:variable>
             <xsl:call-template name="str:_replace">
                <xsl:with-param name="string" select="$string" />
                <xsl:with-param name="replacements" select="exsl:node-set($sorted-replacements-rtf)/replace" />
             </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
             <xsl:message terminate="yes">
                ERROR: template implementation of str:replace relies on exsl:node-set().
             </xsl:message>
          </xsl:otherwise>
       </xsl:choose>
    </xsl:template>

    <xsl:template name="str:_replace">
      <xsl:param name="string" select="''" />
      <xsl:param name="replacements" select="/.." />
      <xsl:choose>
        <xsl:when test="not($string)" />
        <xsl:when test="not($replacements)">
          <xsl:value-of select="$string" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="replacement" select="$replacements[1]" />
          <xsl:variable name="search" select="$replacement/@search" />
          <xsl:choose>
            <xsl:when test="not(string($search))">
              <xsl:value-of select="substring($string, 1, 1)" />
              <xsl:copy-of select="$replacement/node()" />
              <xsl:call-template name="str:_replace">
                <xsl:with-param name="string" select="substring($string, 2)" />
                <xsl:with-param name="replacements" select="$replacements" />
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="contains($string, $search)">
              <xsl:call-template name="str:_replace">
                <xsl:with-param name="string" select="substring-before($string, $search)" />
                <xsl:with-param name="replacements" select="$replacements[position() > 1]" />
              </xsl:call-template>      
              <xsl:copy-of select="$replacement/node()" />
              <xsl:call-template name="str:_replace">
                <xsl:with-param name="string" select="substring-after($string, $search)" />
                <xsl:with-param name="replacements" select="$replacements" />
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="str:_replace">
                <xsl:with-param name="string" select="$string" />
                <xsl:with-param name="replacements" select="$replacements[position() > 1]" />
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

</xsl:stylesheet>