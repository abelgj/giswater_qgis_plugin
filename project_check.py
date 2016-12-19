# -*- coding: utf-8 -*-
"""
/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""
from PyQt4.QtCore import QCoreApplication, QObject, QSettings, QTranslator
from PyQt4.QtGui import QAction, QActionGroup, QIcon   

import os.path
import sys  


class ProjectCheck(QObject):
   
    def __init__(self, Giswater):
        ''' Constructor '''
        
        # Initialize instance attributes
        self.giswater = Giswater
        print type(self.giswater)
        
        
    def test(self):
        
        print "test"
        
        
    def project_read(self):
        
        # Hide all toolbars
        self.hide_toolbars()
                    
        # Check if we have any layer loaded
        layers = self.iface.legendInterface().layers()
        if len(layers) == 0:
            return    
        
        # Initialize variables
        self.layer_arc = None
        self.layer_node = None
        self.layer_connec = None
        self.layer_gully = None
        self.layer_version = None
        
        # Iterate over all layers to get the ones specified in 'db' config section 
        for cur_layer in layers:     
            layer_source = self.controller.get_layer_source(cur_layer)
            uri_table = layer_source['table']
            if uri_table is not None:
                if self.table_arc in uri_table:  
                    self.layer_arc = cur_layer
                if self.table_node in uri_table:  
                    self.layer_node = cur_layer
                if self.table_connec in uri_table:  
                    self.layer_connec = cur_layer
                if self.table_gully in uri_table:  
                    self.layer_gully = cur_layer
                if self.table_version in uri_table: 
                    self.layer_version = cur_layer     
        
        # Check if table 'version' exists
        if self.layer_version is None:
            self.controller.show_warning("Layer version not found")
            return
                 
        # Get schema name from table 'version'
        # Check if really exists
        layer_source = self.controller.get_layer_source(self.layer_version)  
        self.schema_name = layer_source['schema']
        schema_name = self.schema_name.replace('"', '')
        if self.schema_name is None or not self.dao.check_schema(schema_name):
            self.controller.show_warning("Schema not found: "+self.schema_name)            
            return
        
        # Set schema_name in controller and in config file
        self.controller.plugin_settings_set_value("schema_name", self.schema_name)   
        self.controller.set_schema_name(self.schema_name)    
        
        # Cache error message with log_code = -1 (uncatched error)
        self.controller.get_error_message(-1)        
        
        # Set SRID from table node
        sql = "SELECT Find_SRID('"+schema_name+"', '"+self.table_node+"', 'the_geom');"
        row = self.dao.get_row(sql)
        if row:
            self.srid = row[0]   
            self.controller.plugin_settings_set_value("srid", self.srid)                           
        
        # Search project type in table 'version'
        self.search_project_type()
        
        self.controller.set_actions(self.actions)
                                         
        # Set layer custom UI form and init function   
        if self.load_custom_forms:
            if self.layer_arc is not None:    
                self.set_layer_custom_form(self.layer_arc, 'arc')   
            if self.layer_node is not None:       
                self.set_layer_custom_form(self.layer_node, 'node')                                       
            if self.layer_connec is not None:       
                self.set_layer_custom_form(self.layer_connec, 'connec')
            if self.layer_gully is not None:       
                self.set_layer_custom_form(self.layer_gully, 'gully')   
                      
        # Manage current layer selected     
        self.current_layer_changed(self.iface.activeLayer())   
        
        # Set objects for map tools classes
        self.set_map_tool('mg_move_node')
        self.set_map_tool('mg_delete_node')
        self.set_map_tool('mg_mincut')
        self.set_map_tool('mg_flow_trace')
        self.set_map_tool('mg_flow_exit')
        self.set_map_tool('mg_connec_tool')
        self.set_map_tool('mg_extract_raster_value')

        # Set SearchPlus object
        self.set_search_plus()
        
        