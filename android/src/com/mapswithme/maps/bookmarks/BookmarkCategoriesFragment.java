package com.mapswithme.maps.bookmarks;

import android.content.Intent;
import android.os.Bundle;
import android.support.annotation.LayoutRes;
import android.view.MenuItem;
import android.view.View;
import com.cocosw.bottomsheet.BottomSheet;
import com.mapswithme.maps.R;
import com.mapswithme.maps.base.BaseMwmRecyclerFragment;
import com.mapswithme.maps.bookmarks.data.BookmarkCategory;
import com.mapswithme.maps.bookmarks.data.BookmarkManager;
import com.mapswithme.maps.dialog.EditTextDialogFragment;
import com.mapswithme.maps.widget.recycler.RecyclerClickListener;
import com.mapswithme.maps.widget.recycler.RecyclerLongClickListener;
import com.mapswithme.util.BottomSheetHelper;
import com.mapswithme.util.sharing.SharingHelper;

public class BookmarkCategoriesFragment extends BaseMwmRecyclerFragment
                                     implements EditTextDialogFragment.OnTextSaveListener,
                                                MenuItem.OnMenuItemClickListener,
                                                RecyclerClickListener,
                                                RecyclerLongClickListener
{
  private int mSelectedPosition;
  private BookmarkCategoriesAdapter mAdapter;

  @Override
  protected @LayoutRes int getLayoutRes()
  {
    return R.layout.recycler_default;
  }

  @Override
  public void onViewCreated(View view, Bundle savedInstanceState)
  {
    super.onViewCreated(view, savedInstanceState);

    mAdapter = new BookmarkCategoriesAdapter(getActivity());
    mAdapter.setOnClickListener(this);
    mAdapter.setOnLongClickListener(this);
    getRecyclerView().setAdapter(mAdapter);
  }

  @Override
  public void onResume()
  {
    super.onResume();
    mAdapter.notifyDataSetChanged();
  }

  @Override
  public void onPause()
  {
    super.onPause();
    BottomSheetHelper.free();
  }

  @Override
  public void onSaveText(String text)
  {
    final BookmarkCategory category = BookmarkManager.INSTANCE.getCategoryById(mSelectedPosition);
    category.setName(text);
    mAdapter.notifyDataSetChanged();
  }

  @Override
  public boolean onMenuItemClick(MenuItem item)
  {
    switch (item.getItemId())
    {
    case R.id.set_show:
      BookmarkManager.INSTANCE.toggleCategoryVisibility(mSelectedPosition);
      mAdapter.notifyDataSetChanged();
      break;

    case R.id.set_share:
      SharingHelper.shareBookmarksCategory(getActivity(), mSelectedPosition);
      break;

    case R.id.set_delete:
      BookmarkManager.INSTANCE.deleteCategory(mSelectedPosition);
      mAdapter.notifyDataSetChanged();
      break;

    case R.id.set_edit:
      EditTextDialogFragment.show(getString(R.string.bookmark_set_name),
                                  BookmarkManager.INSTANCE.getCategoryById(mSelectedPosition).getName(),
                                  getString(R.string.rename), getString(R.string.cancel), this);
      break;
    }

    return true;
  }

  @Override
  public void onLongItemClick(View v, int position)
  {
    mSelectedPosition = position;

    BookmarkCategory category = BookmarkManager.INSTANCE.getCategoryById(mSelectedPosition);
    BottomSheet bs = BottomSheetHelper.create(getActivity())
        .title(category.getName())
        .sheet(R.menu.menu_bookmark_categories)
        .listener(this)
        .build();

    MenuItem show = bs.getMenu().getItem(0);
    show.setIcon(category.isVisible() ? R.drawable.ic_hide
                                      : R.drawable.ic_show);
    show.setTitle(category.isVisible() ? R.string.hide
                                       : R.string.show);
    bs.show();
  }

  @Override
  public void onItemClick(View v, int position)
  {
    startActivity(new Intent(getActivity(), BookmarkListActivity.class)
                      .putExtra(ChooseBookmarkCategoryFragment.CATEGORY_ID, position));
  }
}
