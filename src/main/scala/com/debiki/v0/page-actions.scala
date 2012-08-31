// Copyright (c) 2012 Kaj Magnus Lindberg (born 1979)

package com.debiki.v0

import java.{util => ju}
import collection.{immutable => imm, mutable => mut}
import Prelude._
import Debate._
import FlagReason.FlagReason


sealed abstract class Action {  // COULD delete, replace with Post:s?
  /** A local id, unique only in the Debate that this action modifies.
    * "?" means unknown.
    */
  def id: String
  require(id != "0")
  require(id nonEmpty)

  /** An id that identifies the login session, which in turn identifies
   *  the user and IP and session creation time.
   */
  def loginId: String

  /** Always None, unless the post was sent from somewhere else than
   *  the relevant Login.ip.
   */
  def newIp: Option[String]
  def ctime: ju.Date

  def textLengthUtf8: Int = 0
}

/** Classifies an action, e.g. tags a Post as being "interesting" and "funny".
 *
 *  If you rate an action many times, only the last rating counts.
 *  - For an authenticated user, his/her most recent rating counts.
 *  - For other users, the most recent rating for the login id / session id
 *    counts.
 *  - Could let different non-authenticated sessions with the same
 *    user name, ip and email overwrite each other's ratings.
 *    But I might as well ask them to login instead? Saves my time, and CPU.
 */
case class Rating (
  id: String,
  postId: String,
  loginId: String,
  newIp: Option[String],
  ctime: ju.Date,
  tags: List[String]
) extends Action


/** Info on all ratings on a certain action, grouped and sorted in
 *  various manners.
 */
// COULD rename to RatingsOnAction?
abstract class SingleActionRatings {

  /** The most recent rating, by authenticated users. */
  def mostRecentByUserId: collection.Map[String, Rating]

  /** The most recent rating, by non authenticated users. */
  // COULD rename to ...ByGuestId
  def mostRecentByNonAuLoginId: collection.Map[String, Rating]

  /** The most recent ratings, for all non authenticated users,
   *  grouped by IP address.
   */
  // COULD rename to ...ByIdtyId
  def allRecentByNonAuIp: collection.Map[String, List[Rating]]

  /** The most recent version of the specified rating.
   *  When you rate an action a second time, the most recent rating
   *  overwrites the older one.
   */
  def curVersionOf(rating: Rating): Rating
}


object FlagReason extends Enumeration {
  type FlagReason = Value
  val Spam, Illegal, /* Copyright Violation */ CopyVio, Other = Value
}

case class Flag(
  id: String,
  postId: String,
  loginId: String,
  newIp: Option[String],
  ctime: ju.Date,
  reason: FlagReason,
  details: String
) extends Action {
  override def textLengthUtf8: Int = details.getBytes("UTF-8").length
}


// ?? Replace with ActionBody, which is a case object or case class +
// text: String (for an article/comment) / tags: List[String] (for ratings).
sealed abstract class PostType
object PostType {

  /** A blog post, or forum questiom or comment. */
  case object Text extends PostType

  /** Edits a Post.text. */
  //case object Edit extends PostType

  /** Makes an Action suggestion take effect.
   */
  case object Publish extends PostType

  /** Meta information describes another Post. */
  // COULD use dedicated PostType:s instead, then the computer/database
  // would understand what is it (but it'd have to parse the Meta.text to
  // understand what is it.
  case object Meta extends PostType

  /** Deletes something, e.g. a post.
   *
   * Instead of the deleted thing information that the thing
   * was deleted is shown, e.g. "3 comments deleted by <someone>".
   */
  // case object Deletion extends PostType

  /** Undoes an action, as if had it never been done.
   *
   * This is different from Delete, because if you delete a post,
   * information is shown on the page that here is a deleted post.
   * However, if you Undo a post, there'll be not a trace of it
   * on the generated page.
   * Initially, though, only Undo:s of Deletion:s and Flag:s will be
   * implemented (so you can undelete an unflag stuff).
   */
  // case object Undo extends PostType

  //sealed abstract trait FlagReason
  //case object FlagSpam extends PostType with FlagReason
}

case class Post(  // COULD merge all actions into Post,
                  // and use different PostType:s (which would include
                  // the payload) for various different actions.
                  // And rename to ... Action? PageAction?

  // is "?" if unknown, or e.g. "?x" if it's unknown.
  // COULD replace w case classes e.g. IdKnown(id)/IdPending(tmpId)/IdUnknown,
  // then it would not be possible to forget to check for "?".
  id: String,
  parent: String,
  ctime: ju.Date,
  loginId: String,
  newIp: Option[String],
  text: String,

  /** The markup language to use when rendering this post.
   */
  markup: String,

  tyype: PostType,

  /** If defined, this is an inline comment and the value
   *  specifies where in the parent post it is to be placed.
   */
  where: Option[String] = None   // COULD move to separate Meta post?
                                 // Benefits: Editing and versioning of
                                 // `where', without affecting this Post.text.
                                // Benefit 2: There could be > 1 meta-Where
                                // for each post, so you could make e.g. a
                                // generic comment that results in ...
                                // ...?? arrows to e.g. 3 other comments ??
) extends Action {
  override def textLengthUtf8: Int = text.getBytes("UTF-8").length
}

case class PostMeta(
  isArticleQuestion: Boolean = false,
  fixedPos: Option[Int] = None
)

// Could rename to Patch? or Diff?
// SHOULD merge into Post and PostType.Edit
case class Edit (
  id: String,
  postId: String,
  ctime: ju.Date,
  loginId: String,
  newIp: Option[String],
  text: String,

  /** Changes the markup henceforth applied to postId's text.
   *
   * None means reuse the current markup.
   */
  newMarkup: Option[String]
) extends Action {
  override def textLengthUtf8: Int = text.getBytes("UTF-8").length
}


/** Edit applications (i.e. when edits are applied).
 *
 *  COULD make generic: applying a Post means it's published.
 *  Applying an Edit means the relevant Post is edited.
 *  Applying a Flag means the relevant Post is hidden.
 *  Applying a Delete means whatever is whatever-happens-when-it's-deleted.
 *  And each Action could have a applied=true/false field?
 *  so they can be applied directly on creation?
 */
// SHOULD merge into Post and use case class PostType.Appl?
case class EditApp(   // COULD rename to Appl?
  id: String,
  editId: String,  // COULD rename to actionId?
  loginId: String,
  newIp: Option[String],
  ctime: ju.Date,

  /** The text after the edit was applied. Needed, in case an `Edit'
   *  contains a diff, not the resulting text itself. Then we'd better not
   *  find the resulting text by applying the diff to the previous
   *  version, more than once -- that wouldn't be future compatible: the diff
   *  algorithm might functioni differently depending on software version
   *  (e.g. because of bugs).
   *  So, only apply the diff algorithm once, to find the EddidApplied.result,
   *  and thereafter always use EditApplied.result.
   *
   *  Update: What! I really don't think the diff alg will change in the
   *  future! Anyone changing the diff file format would be insane,
   *  and would not have been able to write a diff alg at all.
   *  So `result' is *not* needed, except for perhaps improving performance.
   *
   *  COULD change to an Option[String] and define it only one time out of ten?
   *  Then the entire post would be duplicated only 1 time out of 10 times,
   *  and that would hardly affect storage space requirements,
   *  but at the same time improving performance reasonably much ??
   *  Or store cached post texts in a dedicated db table.
   */
  result: String
) extends Action

/** Deletes an action. When actionId (well, postId right now)
 *  is a post, it won't be rendered. If `wholeTree', no reply is shown either.
 *  If actionId is an EditApp, that edit is undone. BAD??! Too complicated??
 *    What does it mean to Delete an EditApp Delete:ion?
 *    Of course it would mean that the Deletion was undone,
 *    that is, Undo, that is, the EditApp would be in effect again,
 *    that is, the Edit would be in effect again.
 *    However I think this is too complicated.
 *    Perhaps it's easier to introduce a Revert class.
 *    And if there are many Apply:s and Revert:s for an Edit,
 *    then the most recent Apply or Revert is in effect.
 *    Benefit: You'd never need to walk along a chain of Delete:s,
 *    to find out which EditApp or Post was actually deleted.
 *    ????
 *  --- Not implemented: --------
 *  If `wholeTree', all edit applications from actionId and up to
 *  delete.ctime are undone.
 *  If actionId is an Edit, the edit will no longer appear in the list of
 *  edits you can choose to apply.
 *  If `wholeTree', no Edit from actionId up to delete.ctime will appear
 *  in the list of edits that can be applied.
 *  -----------------------------
 */
// SHOULD merge into Post and use case class PostType.Deletion?
case class Delete(
  id: String,
  postId: String,  // COULD rename to actionId
  loginId: String,
  newIp: Option[String],
  ctime: ju.Date,
  wholeTree: Boolean,  // COULD rename to `recursively'?
  reason: String  // COULD replace with a Post that is a reply to this Delete?
) extends Action {
  override def textLengthUtf8: Int = reason.getBytes("UTF-8").length
}


// COULD make a Deletion class, and a DelApp (deletion application) class.
// Then sometimes e.g. 3 people must delete a post for it to really
// be deleted. Perhaps DelSug = deletion suggestion?
// And rename Edit to EditSug?
// EditSug & EditApp, + DelSug & DelApp - or join these 4 classes to 2 generic?
// What about Flag and FlagApp? Eventually if flagged as spam e.g. 2 times
// then the post would be automatically hidden?
// What about only one ActionApp class, that applies the relevant action?
// But then e.g. EditApp.result (resulting text) would be gone!?
// And DelApp.wholeTree ... and FlagApp.reason + details.
// Perhaps better have many small specialized classes.


/**
 * Approves or rejects e.g. comments and edits to `targetId`.
 */
case class Review(
  id: String,
  targetId: String,
  loginId: String,
  newIp: Option[String],
  ctime: ju.Date,
  isApproved: Boolean) extends Action {
}


// vim: fdm=marker et ts=2 sw=2 tw=80 fo=tcqwn list
