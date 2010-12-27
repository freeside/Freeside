<?xml version="1.0"?>
<!--
   Copyright (C) 2002  Stanislav Sinyagin
 
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
 
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
 
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

  $Id: extract-skeleton.xsl,v 1.1 2010-12-27 00:04:04 ivan Exp $
  Stanislav Sinyagin <ssinyagin@yahoo.com>

  XSLT Template to transform Torrus configuration into a skeleton of
  subtrees and leaves only.

-->

<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml" encoding="UTF-8" indent="yes" />
<xsl:strip-space elements="*" />

<xsl:template match="/configuration">
  <configuration>
    <creator-info>
      This file is a result of extract-skeleton.xsl template
    </creator-info>
    <xsl:text>
    </xsl:text>
    <xsl:apply-templates />
  </configuration>
</xsl:template>


<xsl:template match="creator-info">
  <creator-info>
    <xsl:value-of select="." />
  </creator-info>
  <xsl:text>
  </xsl:text>
</xsl:template>


<xsl:template match="datasources">
  <datasources>
    <xsl:apply-templates />
  </datasources>
    <xsl:text>
    </xsl:text>
</xsl:template>


<xsl:template match="subtree">
  <xsl:text>
  </xsl:text>
  <subtree name="{@name}">
    <xsl:text> </xsl:text>
    <xsl:apply-templates />
  </subtree>
  <xsl:text>
  </xsl:text>
</xsl:template>


<xsl:template match="leaf">
  <xsl:text>
  </xsl:text>
  <leaf name="{@name}">
    <xsl:text> </xsl:text>
    <xsl:apply-templates />
  </leaf>
  <xsl:text>
  </xsl:text>
</xsl:template>


</xsl:transform>

