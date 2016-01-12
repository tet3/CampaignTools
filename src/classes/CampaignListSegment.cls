/*
    Copyright (c) 2015 Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
 * @author Salesforce.org
 * @group CampaignTools
 * @description A model class that represents a single "segment" of a campaign
 * list.  A "segment" of a campaign list is one part of the criteria that
 * defines the campaign list.
 */
public abstract class CampaignListSegment implements CampaignList.Segment {
    /** @description This segment's id */
    private Id segmentId;

    /** @description The id of the "campaign list" this segment belongs to */
    private Id rootSegmentId;

    /**
     * @description The immediate parent of this segment in the segment tree
     */
    private Id parentId;

    /**
     * @description True if this source is intended to be used to exclude
     * members from the campaign list.  False, otherwise.
     */
    private Boolean isExclusion;

    /**
     * @description This segment's children segments, if it has any
     */
    private List<CampaignList.Segment> children = new List<CampaignList.Segment>();

    /**
     * @description Construct a CampaignListSegment
     * @param segmentId The id of this segment
     * @param rootSegmentId The id of the "campaign list" this segment belongs to
     * @param parentId The immediate parent of this segment
     */
    public CampaignListSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion) {
        this.segmentId = segmentId;
        this.rootSegmentId = rootSegmentId;
        this.parentId = parentId;
        this.isExclusion = isExclusion;
    }

    /**
     * @description get this segment's id
     * @return Id
     */
    public Id getId() {
        return segmentId;
    }

    /**
     * @description get "campaign list" id this segment belongs to
     * @return Id
     */
    public Id getRootSegmentId() {
        return rootSegmentId;
    }

    /**
     * @description get this segment's parent id
     * @return Id
     */
    public Id getParentId() {
        return parentId;
    }

    /**
     * @description Is this segment intended to exclude members or negate
     * child segments?
     *
     * @return Boolean
     */
    public Boolean isExclusion() {
        return isExclusion;
    }

    /**
     * @description Add a child segment to this segment
     * @param term The segment to add as a child.
     * @return void
     */
    public void addChild(CampaignList.Segment child) {
        children.add(child);
    }

    public List<CampaignList.Segment> getChildren() {
        return children;
    }

    /**
     * @description Determine whether the given CampaignListMember meets
     * the criteria of *this segment*.  If the segment is a grouping node, i.e.
     * 'And' and 'Or' segments, then this will evaluate the criteria
     * recursively for each term.
     *
     * @return Boolean (true if the CampaignListMember is eligible by the criteria of the criteria sub-tree represented by this segment.
     */
    public abstract Boolean meetsCriteria(CampaignList.Member m);

    public TreeIterator iterator() {
        return new TreeIterator(this);
    }

    public class TreeIterator implements Iterator<CampaignList.Segment> {
        private List<CampaignList.Segment> nextSegments = new List<CampaignList.Segment>();

        public TreeIterator(CampaignList.Segment rootSegment) {
            nextSegments.add(rootSegment);
        }

        public Boolean hasNext() {
            return !nextSegments.isEmpty();
        }

        public CampaignList.Segment next() {
            CampaignList.Segment next = nextSegments.remove(nextSegments.size() - 1);
            nextSegments.addAll(next.getChildren());
            return next;
        }
    }

    /**
     * @author Salesforce.org
     * @group CampaignTools
     * @description This is a specific type of CampaignListSegment that
     * represents an 'AND' segment
     */
    public class AndSegment extends CampaignListSegment {
        /**
         * @description Construct an AndSegment
         * @param segmentId The id of this segment
         * @param rootSegmentId The id of the "campaign list" this segment belongs to
         * @param parentId The immediate parent of this segment
         */
        public AndSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion) {
            super(segmentId, rootSegmentId, parentId, isExclusion);
        }

        /**
         * @description Determine whether the given CampaignListMember meets
         * the criteria of all of the terms within this AND grouping of
         * segments.  A CampaignListSegment can only return a valid result if
         * it has at least one valid child.  If this CampaignListSegment is
         * not valid, then this method will return null.
         *
         * @param m The CampaignListMember to determine whether eligible for inclusion in a campaign list
         * @return Boolean (true if the given CampaignListMember is eligible by the criteria of this segment, false if it isn't eligible, or null if the segment is not valid)
         */
        public override Boolean meetsCriteria(CampaignList.Member m) {
            /*
             Since this node can only return a valid result if it has at
             least one valid child, we will keep track of the number of
             valid children we encounter while iterating over this node's
             children (if any).  As we ask each child node whether the given
             member meets its criteria, we check if the child node returns a
             valid result (i.e., not null).  If the child node returns null,
             indicating an invalid child node, we skip that child node in
             the iteration and do not increment the valid child node
             counter.  If we did get a valid result (i.e. a boolean) from
             the child node, we use that result to potentially invalidate
             our assumption that this node should return true (since a valid
             'and' node is false if at least one of its children is false,
             otherwise true).  Since the child node returned a valid result,
             we increment the valid child count.  Finally, after we've
             iterated over all of the child nodes, we return null if this
             node did not have at least one valid child, otherwise we
             return the accumulated result of this node, negating it if
             this node is negated (i.e. if isExclusion is true).
            */
            Boolean meetsCriteria = true;
            Integer numberOfValidChildren = 0;

            List<Boolean> childCriteria = new List<Boolean>();
            for (CampaignList.Segment child : children) {
                Boolean childMeetsCriteria = child.meetsCriteria(m);
                if (null == childMeetsCriteria) continue;
                meetsCriteria &= childMeetsCriteria;
                numberOfValidChildren++;
                if (!meetsCriteria) break;
            }

            if (numberOfValidChildren < 1) {
                return null;
            }

            return isExclusion ^ meetsCriteria;
        }
    }

    /**
     * @author Salesforce.org
     * @group CampaignTools
     * @description This is a specific type of CampaignListSegment that
     * represents an 'OR' segment
     */
    public class OrSegment extends CampaignListSegment {
        /**
         * @description Construct an OrSegment
         * @param segmentId The id of this segment
         * @param rootSegmentId The id of the "campaign list" this segment belongs to
         * @param parentId The immediate parent of this segment
         */
        public OrSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion) {
            super(segmentId, rootSegmentId, parentId, isExclusion);
        }

        /**
         * @description Determine whether the given CampaignListMember meets
         * the criteria of all of the terms within this OR grouping of
         * segments.  A CampaignListSegment can only return a valid result if
         * it has at least one valid child.  If this CampaignListSegment is
         * not valid, then this method will return null.
         *
         * @param m The CampaignListMember to determine whether eligible for inclusion in a campaign list
         * @return Boolean (true if the given CampaignListMember is eligible by the criteria of this segment, false if it isn't eligible, or null if the segment is not valid)
         */
        public override Boolean meetsCriteria(CampaignList.Member m) {
            /*
             Since this node can only return a valid result if it has at
             least one valid child, we will keep track of the number of
             valid children we encounter while iterating over this node's
             children (if any).  As we ask each child node whether the given
             member meets its criteria, we check if the child node returns a
             valid result (i.e., not null).  If the child node returns null,
             indicating an invalid child node, we skip that child node in
             the iteration and do not increment the valid child node
             counter.  If we did get a valid result (i.e. a boolean) from
             the child node, we use that result to potentially invalidate
             our assumption that this node should return false (since a valid
             'or' node is true if at least one of its children is true,
             otherwise false).  Since the child node returned a valid result,
             we increment the valid child count.  Finally, after we've
             iterated over all of the child nodes, we return null if this
             node did not have at least one valid child, otherwise we
             return the accumulated result of this node, negating it if
             this node is negated (i.e. if isExclusion is true).
            */
            Boolean meetsCriteria = false;
            Integer numberOfValidChildren = 0;

            List<Boolean> childCriteria = new List<Boolean>();
            for (CampaignList.Segment child : children) {
                Boolean childMeetsCriteria = child.meetsCriteria(m);
                if (null == childMeetsCriteria) continue;
                meetsCriteria |= childMeetsCriteria;
                numberOfValidChildren++;
                if (meetsCriteria) break;
            }

            if (numberOfValidChildren < 1) {
                return null;
            }

            return isExclusion ^ meetsCriteria;
        }
    }

    /**
     * @author Salesforce.org
     * @group CampaignTools
     * @description This is a specific type of CampaignListSegment that
     * represents a 'SOURCE' segment
     */
    public abstract class SourceSegment extends CampaignListSegment {
        /**
         * @description The id of the source this segment corresponds to, i.e.
         * a Report id or a Campaign id, etc.
         */
        private Id sourceId;

        /**
         * @description Construct a SourceSegment
         * @param segmentId The id of this segment
         * @param rootSegmentId The id of the "campaign list" this segment belongs to
         * @param parentId The immediate parent of this segment
         */
        public SourceSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion, Id sourceId) {
            super(segmentId, rootSegmentId, parentId, isExclusion);
            this.sourceId = sourceId;
        }

        /**
         * @description get the id of the source this segment corresponds to
         * @return Id
         */
        public Id getSourceId() {
            return sourceId;
        }

        /**
         * @description Determine whether the given CampaignListMember is
         * eligible for inclusion in a campaign list based on whether the
         * CampaignListMember was found in this segment's source.
         *
         * @param m The CampaignListMember to test for eligibility
         * @return Boolean (True if the CampaignListMember was found in this segment's source and this is not an exclusion source, or if the CampaignListMember was *not* found in this segment's source and this is an exclusion source. False, otherwise)
         */
        public override Boolean meetsCriteria(CampaignList.Member m) {
            if (isExclusion) {
                return !m.isFromSource(sourceId);
            } else {
                return m.isFromSource(sourceId);
            }
        }

        /**
         * @description Get the name of this source.  Note that this may
         * execute a SOQL query to find the name of this source using the
         * sourceId.
         *
         * @return String
         */
        public String getSourceName() {
            return CampaignList.getSegmentMapper().getSourceNameById(sourceId);
        }

        /**
         * @description Get an appropriate BatchableSequence.Batch class that
         * can be executed to retrieve CampaignListMembers from this source and
         * persist those members to the database
         */
        public abstract BatchableSequence.Batch getBatchProcessor();
    }

    /**
     * @author Salesforce.org
     * @group CampaignTools
     * @description This is a specific type of SourceSegment that represents a
     * Campaign 'SOURCE' segment
     */
    public class CampaignSourceSegment extends SourceSegment {
        /**
         * @description Construct a CampaignSourceSegment
         * @param segmentId The id of this segment
         * @param rootSegmentId The id of the "campaign list" this segment belongs to
         * @param parentId The immediate parent of this segment
         * @param sourceId The id of the source Campaign
         * @param isExclusion True if this source is intended to exclude members that are found in the given campaign.  False, otherwise.
         */
        public CampaignSourceSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion, Id sourceId) {
            super(segmentId, rootSegmentId, parentId, isExclusion, sourceId);
        }

        /**
         * @description Get an appropriate BatchableSequence.Batch class that
         * can be executed to retrieve CampaignListMembers from this source and
         * persist those members to the database.  In this case, it will return
         * a BatchableSequence.Batch class appropriate for retrieving
         * CampaignListMembers from an existing Campaign.
         */
        public override BatchableSequence.Batch getBatchProcessor() {
            CampaignListFromCampaignBatch batch = new CampaignListFromCampaignBatch(
                rootSegmentId,
                sourceId,
                getSourceName()
            );

            batch.setScope(10000);

            return batch;
        }
    }

    /**
     * @author Salesforce.org
     * @group CampaignTools
     * @description This is a specific type of SourceSegment that represents a
     * Report 'SOURCE' segment
     */
    public class ReportSourceSegment extends SourceSegment {
        /**
         * @description the name of the column in the source report that holds
         * the id of the related Contact or Lead
         */
        private String columnName;

        /**
         * @description Construct a ReportSourceSegment
         * @param segmentId The id of this segment
         * @param rootSegmentId The id of the "campaign list" this segment belongs to
         * @param parentId The immediate parent of this segment
         * @param sourceId The id of the source Report
         * @param isExclusion True if this source is intended to exclude members that are found in the given report.  False, otherwise.
         * @param columnName the name of the column in the source report that holds the id of the related Contact or Lead
         */
        public ReportSourceSegment(Id segmentId, Id rootSegmentId, Id parentId, Boolean isExclusion, Id sourceId, String columnName) {
            super(segmentId, rootSegmentId, parentId, isExclusion, sourceId);
            this.columnName = columnName;
        }

        /**
         * @description Get the column name of the report that this source
         * segment is intending to use to retrieve values from the report
         *
         * @return String
         */
        public String getColumnName() {
           return columnName;
        }

        /**
         * @description Get an appropriate BatchableSequence.Batch class that
         * can be executed to retrieve CampaignListMembers from this source and
         * persist those members to the database.  In this case, it will return
         * a BatchableSequence.Batch class appropriate for retrieving
         * CampaignListMembers from a Report.
         */
        public override BatchableSequence.Batch getBatchProcessor() {
            CampaignListFromReportBatch batch = new CampaignListFromReportBatch(
                rootSegmentId,
                sourceId,
                columnName,
                getSourceName()
            );

            batch.setScope(2000);

            return batch;
        }
    }
}